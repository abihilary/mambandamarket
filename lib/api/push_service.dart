import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../Service/ChatRoomScreen.dart';
import '../navigation.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'repositories.dart';

/// Notifications that reach the app when it is not running.
///
/// Realtime (added alongside the unread badge) only ever spoke to an app that
/// was open. Close it, or let the OS reclaim it, and a message waited until
/// somebody happened to look — which for a marketplace means a seller answering
/// a buyer's question the next morning. A socket cannot fix that; nothing in
/// the process is alive to hold one. Only the platform's own push channel can,
/// which is what this is.
///
/// Everything here is optional at runtime. Without Firebase configured — no
/// `google-services.json` in the Android build — [init] finds no default app,
/// says so once, and the rest of the app carries on exactly as before. Push is
/// an addition to how messages arrive, never a prerequisite for it.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channelId = 'messages';

  final _local = FlutterLocalNotificationsPlugin();

  /// Whether Firebase actually came up. False on a build with no config, and
  /// on any platform we have not wired (this ships on Android).
  bool _available = false;

  /// The token currently registered with the API, so a refresh that returns
  /// the same value does not re-POST it and sign-out knows what to delete.
  String? _registered;

  bool _wired = false;

  /// The conversation the user is looking at, if any.
  ///
  /// Set by [ChatRoomScreen]. A notification for the thread already on screen
  /// is noise — the message is right there — so the foreground handler skips
  /// it. Notifications for *other* threads still show, which is the point.
  static String? activeConversationId;

  /// Bring up Firebase and the local notification channel. Safe to call once,
  /// from main(), before the app has signed anybody in.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      // No google-services.json in this build. Not an error worth surfacing to
      // a user: the app works, closed-app delivery just does not.
      debugPrint('[push] Firebase unavailable, push disabled ($e)');
      _available = false;
      return;
    }

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openConversation(response.payload),
    );

    // Android 8+ drops any notification addressed to a channel that does not
    // exist on the device, silently and with no error anywhere. The server
    // addresses 'messages', so 'messages' has to be created here first.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Messages',
          description: 'New messages from buyers and sellers.',
          importance: Importance.high,
        ));

    _wire();

    // Registration follows the session: a token is meaningless without knowing
    // whose phone it is, and it must not outlive the account on it.
    AuthService.instance.isSignedIn.addListener(_onAuthChanged);
    if (AuthService.instance.isSignedIn.value) unawaited(register());
  }

  void _wire() {
    if (_wired) return;
    _wired = true;

    // App in the foreground. Android delivers the payload but displays nothing
    // itself, so anything the user should see has to be raised here.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App was backgrounded and the user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _openConversation(m.data['conversation_id'] as String?),
    );

    // A rotated token is a token the server no longer has. Without this the
    // phone quietly stops receiving anything, and nothing looks broken.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registered = null;
      unawaited(_send(token));
    });
  }

  /// The notification that launched a terminated app, if that is what happened.
  ///
  /// Called after the first frame rather than during startup: the Navigator has
  /// to exist before anything can be pushed onto it.
  ///
  /// This is the case push exists for — the app was not running, which is why
  /// a notification was the only thing that could reach them — so it is also
  /// the case most likely to race the session being restored from disk. The
  /// wait below is that race, handled.
  Future<void> handleLaunchNotification() async {
    if (!_available) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;
    if (!await _awaitSession()) return;
    _openConversation(initial.data['conversation_id'] as String?);
  }

  /// Wait, briefly, for a restored session.
  ///
  /// Fetching the thread is an authenticated call, and on a cold start the
  /// stored session has usually not been read back yet. Without this the tap
  /// resolved to "could not open conversation" and dropped the user on the
  /// home feed — the one moment the app most needed to get this right.
  Future<bool> _awaitSession({
    Duration limit = const Duration(seconds: 10),
  }) async {
    final signedIn = AuthService.instance.isSignedIn;
    if (signedIn.value) return true;
    final completer = Completer<bool>();
    void listener() {
      if (signedIn.value && !completer.isCompleted) completer.complete(true);
    }

    signedIn.addListener(listener);
    final timer = Timer(limit, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      signedIn.removeListener(listener);
    }
  }

  void _onAuthChanged() {
    if (AuthService.instance.isSignedIn.value) {
      unawaited(register());
    } else {
      _registered = null;
    }
  }

  /// Ask for permission if needed, then hand the token to the API.
  ///
  /// On Android 13+ this is what raises the runtime notification prompt. A
  /// refusal is a normal outcome, not a failure: we stop, and the app is
  /// otherwise unaffected.
  Future<void> register() async {
    if (!_available) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] notifications declined');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _send(token);
    } catch (e) {
      debugPrint('[push] registration failed ($e)');
    }
  }

  Future<void> _send(String token) async {
    if (token == _registered) return;
    if (!AuthService.instance.isSignedIn.value) return;
    try {
      await ApiClient.instance.post('/devices', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      _registered = token;
    } catch (e) {
      // Offline at launch is the common case. The next sign-in or token
      // refresh tries again; nothing here is worth interrupting anybody over.
      debugPrint('[push] could not register device ($e)');
    }
  }

  /// Stop notifying this phone. Called from sign-out *before* the session is
  /// torn down, because deleting a device token is an authenticated request.
  Future<void> unregister() async {
    final token = _registered;
    _registered = null;
    if (token == null) return;
    try {
      await ApiClient.instance.delete('/devices/$token');
    } catch (e) {
      debugPrint('[push] could not unregister device ($e)');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // The badge and the inbox should move whether or not anything is shown.
    unawaited(() async {
      try {
        await ChatRepository.instance.refresh();
      } catch (_) {
        // Realtime and the shell's sweep both cover this. Nothing to do.
      }
    }());

    final conversationId = message.data['conversation_id'] as String?;
    if (conversationId != null && conversationId == activeConversationId) return;

    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: conversationId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: conversationId,
    );
  }

  /// Open the thread a notification refers to.
  ///
  /// The conversation is fetched rather than reconstructed from the payload:
  /// the notification carries an id and nothing else, deliberately, so the
  /// listing, the counterparty and the unread count all come back over the
  /// authenticated call that already knows the read rules.
  void _openConversation(String? conversationId) {
    if (conversationId == null || conversationId.isEmpty) return;
    unawaited(() async {
      try {
        final thread = await ChatRepository.instance.thread(conversationId);
        final navigator = rootNavigatorKey.currentState;
        if (navigator == null) return;
        await navigator.push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(conversation: thread),
        ));
      } catch (e) {
        // A deleted thread, or a tap while signed out. Landing on the app
        // rather than an error screen is the right failure here.
        debugPrint('[push] could not open conversation $conversationId ($e)');
      }
    }());
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'cache_rules.dart';
import 'chat_attachment_cache.dart';
import 'chat_store.dart';
import 'notification_repository.dart';
import 'offline_cache.dart';
import 'repositories.dart';

/// What the app knows from the device, and whose it is.
///
/// [boot] opens the stores before the first frame (beside Supabase, not after
/// it); [restore] paints the profile, favourites, inbox and notifications from
/// them synchronously, so the first screens show what they showed last time
/// while the network revalidates. [switchTo] runs on every change of the
/// signed-in account and makes sure nothing of the previous account survives
/// in memory, in flight, or (for a different account) on disk.
abstract final class SavedState {
  static final ValueNotifier<int> _session = ValueNotifier(0);

  /// Bumped after every [switchTo]. The shell restarts realtime on it.
  static ValueListenable<int> get session => _session;

  /// Opens the stores and installs the write hook. Run alongside
  /// Supabase.initialize.
  static Future<void> boot() async {
    await OfflineCache.init();
    await ChatStore.init();
    CacheRules.install(ApiClient.instance);
    // The 1.0.46 store is not migrated, only deleted, and not on the way to
    // the first frame.
    unawaited(Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        await Hive.deleteBoxFromDisk('api_cache_v1');
      } catch (e) {
        debugPrint('[offline] could not delete the v1 store: $e');
      }
    }));
  }

  /// Paints memory from the device for the current account. Synchronous; run
  /// once Supabase is up and AuthService exists.
  static void restore() {
    String? uid;
    try {
      uid = AuthService.instance.userId;
    } catch (e) {
      debugPrint('[saved] no auth yet: $e');
      return;
    }
    unawaited(_adopt(uid));
    _paint(uid);
  }

  static void _paint(String? uid) {
    void step(String name, void Function() f) {
      try {
        f();
      } catch (e) {
        debugPrint('[saved] restore $name failed: $e');
      }
    }

    if (uid != null) {
      step('me', AuthService.instance.restoreMe);
      step('favourites', FavoritesRepository.instance.restore);
      step('inbox', ChatRepository.instance.restore);
      step('notifications', NotificationRepository.instance.restore);
    }
    step('categories', () => ListingsRepository.instance.savedCategories());
  }

  static Future<void> _adopt(String? uid) async {
    try {
      final prev = await OfflineCache.adopt(uid);
      await _wipeOthers(uid, prev);
    } catch (e) {
      debugPrint('[saved] adopt failed: $e');
    }
  }

  static Future<void> _wipeOthers(String? uid, String? prev) async {
    if (uid != null && prev != null && prev != uid) {
      await ChatStore.removeOtherUids(uid);
      await _emptyAttachments();
    }
    if (uid == null && kIsWeb) await ChatStore.clear();
  }

  static Future<void> _emptyAttachments() async {
    try {
      await chatAttachmentCache.emptyCache();
    } catch (e) {
      debugPrint('[saved] attachment cache: $e');
    }
  }

  /// The signed-in account changed: sign-in, sign-out, an expired session,
  /// another account.
  static Future<void> switchTo(String? uid) async {
    resetMemory();
    try {
      final prev = await OfflineCache.newSession(uid);
      await _wipeOthers(uid, prev);
    } catch (e) {
      debugPrint('[saved] switch failed: $e');
    }
    if (uid != null) _paint(uid);
    _session.value++;
  }

  /// Forget, in memory, everything that belongs to an account.
  static void resetMemory() {
    void step(String name, void Function() f) {
      try {
        f();
      } catch (e) {
        debugPrint('[saved] reset $name failed: $e');
      }
    }

    step('favourites', FavoritesRepository.instance.reset);
    step('inbox', () => unawaited(ChatRepository.instance.reset()));
    step('notifications', NotificationRepository.instance.clear);
    step('me', () => AuthService.instance.me.value = null);
  }

  /// Sign-out: every store emptied, on both platforms.
  static Future<void> wipeAll() async {
    await OfflineCache.clear();
    await ChatStore.clear();
    await _emptyAttachments();
    resetMemory();
  }
}

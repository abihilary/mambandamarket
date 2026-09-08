import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_share.dart';
import 'repositories.dart';

/// Whether a share is even possible, and why not when it is not.
enum ShareOutcome { ok, servicesOff, denied, deniedForever, failed }

/// Drives one live location share.
///
/// Only ever one at a time, app-wide. Two running shares would mean two timers
/// waking the GPS and, worse, a "stop sharing" button that stops whichever one
/// the screen happens to know about while the other keeps broadcasting.
///
/// Nothing here runs in the background. The app has no background-location
/// permission and should not have one: sharing stops mattering the moment the
/// person who started it cannot see that it is running.
class LiveLocation {
  LiveLocation._();
  static final LiveLocation instance = LiveLocation._();

  /// The share currently running, or null. Watched by the composer so the
  /// "sharing" banner and the bubble agree without either polling.
  final ValueNotifier<LocationShare?> active = ValueNotifier(null);

  StreamSubscription<Position>? _positions;
  Timer? _deadline;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  bool isRunningFor(String shareId) => active.value?.id == shareId;

  /// Ask the platform where we are, prompting if it has not been asked.
  ///
  /// Returns null on any refusal; the outcome tells the caller which sentence
  /// to show. Only call this from something the user pressed.
  static Future<({Position? position, ShareOutcome outcome})> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (position: null, outcome: ShareOutcome.servicesOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (position: null, outcome: ShareOutcome.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return (position: null, outcome: ShareOutcome.denied);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: shareAccuracy,
          timeLimit: Duration(seconds: 25),
        ),
      );
      return (position: p, outcome: ShareOutcome.ok);
    } catch (e) {
      debugPrint('[location] could not read a position ($e)');
      return (position: null, outcome: ShareOutcome.failed);
    }
  }

  /// How precisely a share reports.
  ///
  /// The manifest removes ACCESS_FINE_LOCATION on purpose — a precise point on
  /// a listing is a private seller's doorstep — so this is the coarse tier and
  /// asking for more here would only be a lie. It is a single constant because
  /// raising it is a one-line change once the manifest and Play's data-safety
  /// form say precise location is collected.
  static const shareAccuracy = LocationAccuracy.medium;

  /// Begin following [share], posting each movement to its conversation.
  void follow(LocationShare share) {
    if (!share.isRunning) return;
    stop(notifyServer: false);
    active.value = share;

    _positions = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: shareAccuracy,
        // Twenty-five metres, so standing still costs nothing. A time-based
        // timer would wake the GPS every few seconds to report the same point.
        distanceFilter: 25,
      ),
    ).listen(_onMoved, onError: (Object e) {
      debugPrint('[location] position stream failed ($e)');
      stop();
    });

    final ends = share.expiresAt;
    if (ends != null) {
      final left = ends.difference(DateTime.now());
      // The server stops honouring updates at the deadline anyway; this is so
      // the phone stops asking, and the banner goes away by itself.
      _deadline = Timer(left.isNegative ? Duration.zero : left, () => stop(notifyServer: false));
    }
  }

  Future<void> _onMoved(Position p) async {
    final share = active.value;
    if (share == null) return;
    // A floor under the stream's own filter: a phone in a moving car can
    // produce a fix every second, and none of those are worth a request.
    if (DateTime.now().difference(_lastSent) < const Duration(seconds: 10)) return;
    _lastSent = DateTime.now();

    final moved = await ChatRepository.instance.moveShare(
      share.conversationId,
      share.id,
      lat: p.latitude,
      lng: p.longitude,
      accuracyM: p.accuracy,
    );
    if (moved == null) {
      // The server says it is no longer running — expired, or stopped from
      // another device. Believe it rather than keep broadcasting.
      stop(notifyServer: false);
      return;
    }
    active.value = moved;
  }

  /// End the share. [notifyServer] is false only when it has already ended.
  void stop({bool notifyServer = true}) {
    final share = active.value;
    _positions?.cancel();
    _positions = null;
    _deadline?.cancel();
    _deadline = null;
    active.value = null;
    if (share != null && notifyServer) {
      // Fire and forget with its own guard: a failed stop must not leave the
      // UI thinking it is still sharing, and the share expires regardless.
      unawaited(ChatRepository.instance
          .stopShare(share.conversationId, share.id)
          .catchError((Object e) => debugPrint('[location] stop failed ($e)')));
    }
  }
}

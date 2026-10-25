import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// The last answer to every read, kept on the device, for when there is no
/// connection.
///
/// Without it, opening the app on a bus with no signal showed an empty feed,
/// an empty inbox and a "couldn't reach the marketplace" message — as if the
/// app had nothing, when it had shown all of it a minute earlier. Asked for on
/// the Product Workspace ("offline mode": remember the last state, and only say
/// the internet is unavailable when the person tries to change something).
///
/// Sits under [ApiClient.get], so every screen that reads through the API gets
/// it without changes of its own: a successful read is stored, and a read that
/// fails for lack of a connection is answered from the store instead. Writes
/// are never cached or queued — a purchase or a message replayed later, from a
/// stale screen, is worse than being told it did not go.
///
/// Keyed by account and full address, so one person's inbox can never be
/// shown to another who signs in on the same phone; and emptied on sign-out
/// anyway. Bounded, oldest first, because search terms make every query a new
/// address.
class OfflineCache {
  OfflineCache._();

  static const String _boxName = 'api_cache_v1';

  /// Enough for the screens someone actually moves between, small enough that
  /// a long search session cannot grow it without limit.
  static const int maxEntries = 400;

  static Box<String>? _box;

  /// True while the screen in front of the person is showing saved answers
  /// because the last read could not reach the API. Cleared by the next read
  /// that does.
  static final ValueNotifier<bool> showingSaved = ValueNotifier(false);

  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      // Private browsing, a full disk, a corrupt file: the app works exactly as
      // it did before this existed, just without the saved copies.
      debugPrint('[offline] cache unavailable: $e');
      _box = null;
    }
  }

  static String _key(String? userId, Uri uri) => '${userId ?? 'anon'}|$uri';

  static Future<void> save(String? userId, Uri uri, String body) async {
    final box = _box;
    if (box == null) return;
    try {
      await box.put(_key(userId, uri), jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'b': body}));
      if (box.length > maxEntries) await _prune(box);
    } catch (e) {
      debugPrint('[offline] save failed: $e');
    }
  }

  /// The saved body for this address, or null.
  static String? read(String? userId, Uri uri) {
    final raw = _box?.get(_key(userId, uri));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map)['b'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _prune(Box<String> box) async {
    final stamped = <MapEntry<dynamic, int>>[];
    for (final k in box.keys) {
      var t = 0;
      try {
        t = ((jsonDecode(box.get(k) ?? '{}') as Map)['t'] as num?)?.toInt() ?? 0;
      } catch (_) {}
      stamped.add(MapEntry(k, t));
    }
    stamped.sort((a, b) => a.value.compareTo(b.value));
    final drop = stamped.take(box.length - (maxEntries * 3 ~/ 4)).map((e) => e.key);
    await box.deleteAll(drop);
  }

  /// Everything, for sign-out.
  static Future<void> clear() async {
    showingSaved.value = false;
    try {
      await _box?.clear();
    } catch (e) {
      debugPrint('[offline] clear failed: $e');
    }
  }
}

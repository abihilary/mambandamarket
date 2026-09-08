import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'board_model.dart';

/// The boards on the home feed, and the last ones this device saw.
///
/// Same three layers as [RemoteConfig], for the same reason: whatever the API
/// last returned, then the device's cache, then nothing. A launch with no
/// network shows the board it showed yesterday instead of a hole in the feed.
///
/// Nothing here throws. The board is decoration on a marketplace — it must
/// never be able to stop somebody browsing, so every failure resolves to
/// "no board" and the home feed carries on without it.
class BoardRepository {
  BoardRepository._();
  static final BoardRepository instance = BoardRepository._();

  static const homeSlug = 'home';
  static const promoSlug = 'home_promo';

  /// Placements this build knows how to ask for. A board published under any
  /// other slug is simply never fetched — which is how a section added later
  /// reaches an older copy of the app as nothing at all, rather than as a
  /// surprise.
  static const slugs = <String>[homeSlug, promoSlug];

  final Map<String, ValueNotifier<Board?>> _boards = {};
  final Set<String> _loadedOnce = {};

  ValueNotifier<Board?> notifier(String slug) =>
      _boards.putIfAbsent(slug, () => ValueNotifier<Board?>(null));

  /// Every board currently on screen, for the media cache to reconcile against.
  Iterable<Board?> get live => slugs.map((s) => notifier(s).value);

  /// Both placements, in parallel. One failing does not touch the other: each
  /// keeps whatever its own cache held.
  Future<void> loadAll() async => await Future.wait(slugs.map(load));

  /// Read the cache, then refresh from the API.
  ///
  /// Safe to call repeatedly; the home feed calls it on every pull-to-refresh.
  Future<void> load([String slug = homeSlug]) async {
    final board = notifier(slug);
    if (_loadedOnce.add(slug)) {
      await _readCache(slug, board);
    }
    try {
      final json = await ApiClient.instance.get('/boards/$slug') as Map<String, dynamic>;
      final raw = (json['board'] as Map?)?.cast<String, dynamic>();
      board.value = Board.fromJson(raw);
      await _writeCache(slug, raw);
    } catch (e) {
      // Offline, or the endpoint is unhappy. Whatever the cache held stands.
      debugPrint('[board] refresh failed for $slug, keeping cached board ($e)');
    }
  }

  /// The home board keeps the key it has always used, so upgrading does not
  /// throw away the board a device is already holding.
  static String _cacheKey(String slug) =>
      slug == homeSlug ? 'home_board_v1' : 'board_${slug}_v1';

  Future<void> _readCache(String slug, ValueNotifier<Board?> board) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(slug));
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) board.value = Board.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt cache is not worth failing a launch over.
    }
  }

  Future<void> _writeCache(String slug, Map<String, dynamic>? raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (raw == null) {
        // The board was withdrawn or its window closed. Clear it, or the device
        // would keep showing a promotion that ended on Sunday.
        await prefs.remove(_cacheKey(slug));
      } else {
        await prefs.setString(_cacheKey(slug), jsonEncode(raw));
      }
    } catch (_) {
      // Storage unavailable — the value still applies for this session.
    }
  }
}

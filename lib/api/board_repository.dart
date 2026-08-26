import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'board_model.dart';

/// The home board, and the last one this device saw.
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

  static const _kCacheKey = 'home_board_v1';
  static const _slug = 'home';

  final ValueNotifier<Board?> board = ValueNotifier(null);

  bool _loadedOnce = false;

  /// Read the cache, then refresh from the API.
  ///
  /// Safe to call repeatedly; the home feed calls it on every pull-to-refresh.
  Future<void> load() async {
    if (!_loadedOnce) {
      await _readCache();
      _loadedOnce = true;
    }
    try {
      final json = await ApiClient.instance.get('/boards/$_slug') as Map<String, dynamic>;
      final raw = (json['board'] as Map?)?.cast<String, dynamic>();
      board.value = Board.fromJson(raw);
      await _writeCache(raw);
    } catch (e) {
      // Offline, or the endpoint is unhappy. Whatever the cache held stands.
      debugPrint('[board] refresh failed, keeping cached board ($e)');
    }
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) board.value = Board.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt cache is not worth failing a launch over.
    }
  }

  Future<void> _writeCache(Map<String, dynamic>? raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (raw == null) {
        // The board was withdrawn or its window closed. Clear it, or the device
        // would keep showing a promotion that ended on Sunday.
        await prefs.remove(_kCacheKey);
      } else {
        await prefs.setString(_kCacheKey, jsonEncode(raw));
      }
    } catch (_) {
      // Storage unavailable — the value still applies for this session.
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'board_model.dart';

/// Board video, downloaded once and kept.
///
/// Autoplaying video in the home feed is a real cost to somebody on mobile data
/// in Douala, and re-fetching the same clip on every pull-to-refresh would turn
/// one cost into a recurring one. So the file is downloaded once and played
/// from disk thereafter; a refresh that returns the same board costs nothing.
///
/// Entries are keyed by **storage path**, not URL. Paths carry a uuid folder
/// minted at upload, so replacing a clip produces a key this device has never
/// seen — the new video is fetched, and the old one is no longer referenced by
/// any board.
///
/// [reconcile] is what actually removes it. Leaving that to the cache's own LRU
/// would mean a replaced video lingering until enough others pushed it out,
/// which on a device that sees one board a month is indefinitely.
class BoardMediaCache {
  BoardMediaCache._();
  static final BoardMediaCache instance = BoardMediaCache._();

  static const _key = 'board_media';

  final CacheManager _manager = CacheManager(
    Config(
      _key,
      // A backstop, not the policy. reconcile() is the policy.
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 20,
    ),
  );

  /// Paths this device currently holds a file for, so reconcile knows what it
  /// is allowed to remove. Rebuilt from downloads rather than persisted: losing
  /// it costs one re-download, and persisting it adds a way for the record and
  /// the disk to disagree.
  final Set<String> _held = <String>{};

  /// The local file for [url], fetching it the first time.
  ///
  /// Returns null rather than throwing: a video that will not download should
  /// leave its poster on screen, not take the home feed down with it.
  Future<File?> fileFor({required String url, required String path}) async {
    try {
      final info = await _manager.getFileFromCache(path);
      if (info != null) {
        _held.add(path);
        return info.file;
      }
      final downloaded = await _manager.downloadFile(url, key: path);
      _held.add(path);
      return downloaded.file;
    } catch (e) {
      debugPrint('[board] could not cache video $path ($e)');
      return null;
    }
  }

  /// Drop anything the live board no longer refers to.
  ///
  /// Called after every successful board load. A board that swapped its video
  /// yesterday should not still be costing storage today.
  Future<void> reconcile(Board? board) async {
    final keep = board?.mediaPaths ?? const <String>{};
    final stale = _held.difference(keep);
    for (final path in stale) {
      try {
        await _manager.removeFile(path);
        _held.remove(path);
      } catch (_) {
        // Already gone, or the store is busy. It will fall out by LRU.
      }
    }
  }

  /// Everything, for sign-out or a hard reset.
  Future<void> clear() async {
    try {
      await _manager.emptyCache();
      _held.clear();
    } catch (_) {
      // Nothing useful to do if the cache will not empty.
    }
  }
}

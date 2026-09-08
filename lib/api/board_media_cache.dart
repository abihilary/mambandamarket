import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'board_model.dart';

/// Every file the boards currently on screen refer to.
///
/// Pulled out as a plain function so the rule can be tested without a cache
/// manager, a temp directory or a network — the bug it closes was invisible
/// precisely because exercising it needed all three.
Set<String> boardMediaKeepSet(Iterable<Board?> boards) => {
      for (final b in boards)
        if (b != null) ...b.mediaPaths,
    };

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
/// [reconcileAll] is what actually removes it. Leaving that to the cache's own LRU
/// would mean a replaced video lingering until enough others pushed it out,
/// which on a device that sees one board a month is indefinitely.
class BoardMediaCache {
  BoardMediaCache._();
  static final BoardMediaCache instance = BoardMediaCache._();

  static const _key = 'board_media';

  final CacheManager _manager = CacheManager(
    Config(
      _key,
      // A backstop, not the policy. reconcileAll() is the policy.
      stalePeriod: const Duration(days: 60),
      // Two boards share this store now.
      maxNrOfCacheObjects: 40,
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

  /// Drop anything the live boards no longer refer to.
  ///
  /// Called after every successful board load. A board that swapped its video
  /// yesterday should not still be costing storage today.
  ///
  /// Takes every board on screen, not one. There are two now, and reconciling
  /// against a single one would delete the other's clip on every refresh —
  /// turning the one-off download this class exists to guarantee into a charge
  /// somebody pays each time they pull the feed, and popping the other board
  /// back to its poster mid-scroll.
  Future<void> reconcileAll(Iterable<Board?> boards) async {
    final keep = boardMediaKeepSet(boards);
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

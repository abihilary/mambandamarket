import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'chat_sync.dart';
import 'offline_cache.dart';

export 'chat_sync.dart' show StoredThread;

/// Each conversation's newest messages, kept so a chat opens instantly and the
/// next read asks only for what is new (see chat_sync.dart).
///
/// Only rows the server sent are kept: a bubble still sending, or one that
/// failed, never reaches the disk, so nothing is ever re-sent from here and a
/// failed message does not come back after a restart.
///
/// On Android the threads live in a Hive box; on web in memory only, because a
/// browser is more often shared than a phone. Keyed by account, and emptied on
/// sign-out and whenever a different account signs in.
abstract final class ChatStore {
  static const maxThreads = 60;
  static const maxItemsPerThread = 100;
  static const maxChars = 1000000;

  static const String _boxName = 'chat_v1';
  static const Duration _persistEvery = Duration(minutes: 10);

  static Box<String>? _box;
  static final Map<String, StoredThread> _mem = {};

  /// What was last written per thread (signature, cursor, count) and when.
  static final Map<String, String> _persistedSig = {};
  static final Map<String, int> _persistedAt = {};
  static final Map<String, Future<void>> _locks = {};
  static int Function() _clock = () => DateTime.now().millisecondsSinceEpoch;
  static bool _web = kIsWeb;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      // Works from memory for this session.
      debugPrint('[chat] store unavailable: $e');
      _box = null;
    }
  }

  @visibleForTesting
  static Future<void> initForTest(String dir, {int Function()? clock, bool web = false}) async {
    try {
      await _box?.close();
    } catch (_) {}
    _box = null;
    _mem.clear();
    _persistedSig.clear();
    _persistedAt.clear();
    _locks.clear();
    _clock = clock ?? () => DateTime.now().millisecondsSinceEpoch;
    _web = web;
    if (web) return;
    Hive.init(dir);
    _box = await Hive.openBox<String>(_boxName);
  }

  static String _key(String uid, String cid) => '$uid|$cid';
  static String _uidOf(String key) {
    final i = key.indexOf('|');
    return i < 0 ? key : key.substring(0, i);
  }

  static String _mark(StoredThread t) => '${signature(t.items)}#${t.cursor}#${t.count}';

  /// The stored thread, synchronously: memory first, then the disk.
  static StoredThread? read(String uid, String cid) {
    final key = _key(uid, cid);
    final m = _mem[key];
    if (m != null) return m;
    final raw = _box?.get(key);
    if (raw == null) return null;
    try {
      final t = StoredThread.fromJson(jsonDecode(raw));
      if (t == null) return null;
      _mem[key] = t;
      _persistedSig[key] = _mark(t);
      _persistedAt[key] = _clock();
      return t;
    } catch (_) {
      return null;
    }
  }

  /// Serialized per (uid, cid): [edit] sees the state as it is at write time,
  /// so a send landing during a sync is merged, not overwritten. Returns the
  /// new state, or null when rejected ([generation] is no longer
  /// [OfflineCache.generation]: the account changed) or [edit] returned null.
  static Future<StoredThread?> update(String uid, String cid,
      StoredThread? Function(StoredThread? current) edit, {required int generation}) {
    final key = _key(uid, cid);
    final previous = _locks[key] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[key] = done.future;
    return previous.then((_) async {
      try {
        if (generation != OfflineCache.generation) return null;
        final current = read(uid, cid);
        final next = edit(current);
        if (next == null) return null;
        if (identical(next, current)) return current;
        final clean = _sanitize(next);
        _mem[key] = clean;
        await _persist(key, clean);
        return clean;
      } finally {
        if (identical(_locks[key], done.future)) _locks.remove(key);
        done.complete();
      }
    });
  }

  static StoredThread _sanitize(StoredThread t) {
    final items = [
      for (final m in t.items)
        if (!(m['id']?.toString() ?? 'local:').startsWith('local:') && (m['id']?.toString() ?? '').isNotEmpty) m,
    ];
    final capped = items.length > maxItemsPerThread ? items.sublist(items.length - maxItemsPerThread) : items;
    return capped.length == t.items.length ? t : t.copyWith(items: capped);
  }

  /// Written only when something a repaint depends on changed, or ten
  /// minutes after the last write; timestamps otherwise live in memory.
  static Future<void> _persist(String key, StoredThread t) async {
    final box = _box;
    if (box == null || _web) {
      _pruneMemory();
      return;
    }
    final mark = _mark(t);
    final at = _persistedAt[key];
    final now = _clock();
    if (_persistedSig[key] == mark && at != null && now - at < _persistEvery.inMilliseconds) return;
    _persistedSig[key] = mark;
    _persistedAt[key] = now;
    try {
      await box.put(key, jsonEncode(t.toJson()));
    } catch (e) {
      debugPrint('[chat] save failed: $e');
    }
    await _prune();
  }

  static final RegExp _openedField = RegExp(r'"o":(\d+)');

  static int _openedAt(String key) {
    final m = _mem[key];
    if (m != null) return m.openedAt;
    final raw = _box?.get(key);
    if (raw == null) return 0;
    // "o" is written before "i", so the first match is the thread's own.
    return int.tryParse(_openedField.firstMatch(raw)?.group(1) ?? '') ?? 0;
  }

  static Future<void> _prune() async {
    final box = _box;
    if (box == null) return;
    var chars = 0;
    for (final v in box.values) {
      chars += v.length;
    }
    if (box.length <= maxThreads && chars <= maxChars) return;
    final keys = box.keys.cast<String>().toList()
      ..sort((a, b) => _openedAt(a).compareTo(_openedAt(b)));
    final drop = <String>[];
    var n = keys.length;
    for (final k in keys) {
      if (n <= maxThreads && chars <= maxChars) break;
      chars -= box.get(k)?.length ?? 0;
      n--;
      drop.add(k);
    }
    for (final k in drop) {
      _forget(k);
    }
    try {
      await box.deleteAll(drop);
    } catch (e) {
      debugPrint('[chat] prune failed: $e');
    }
  }

  static void _pruneMemory() {
    if (_mem.length <= maxThreads) return;
    final keys = _mem.keys.toList()..sort((a, b) => _mem[a]!.openedAt.compareTo(_mem[b]!.openedAt));
    for (final k in keys.take(_mem.length - maxThreads)) {
      _forget(k);
    }
  }

  static void _forget(String key) {
    _mem.remove(key);
    _persistedSig.remove(key);
    _persistedAt.remove(key);
  }

  /// Opened now. Memory only: it decides which threads are pruned first, and
  /// is written with the thread's next real change.
  static void noteOpened(String uid, String cid) {
    final t = read(uid, cid);
    if (t == null) return;
    _mem[_key(uid, cid)] = t.copyWith(openedAt: _clock());
  }

  static Future<void> remove(String uid, String cid) async {
    final key = _key(uid, cid);
    _forget(key);
    try {
      await _box?.delete(key);
    } catch (e) {
      debugPrint('[chat] remove failed: $e');
    }
  }

  /// Drop every thread of [uid] that is not in [conversationIds]. Only after
  /// a complete inbox from the server.
  static Future<void> retainOnly(String uid, Set<String> conversationIds) async {
    bool stray(String key) => _uidOf(key) == uid && !conversationIds.contains(key.substring(uid.length + 1));
    await _removeWhere(stray);
  }

  /// Another account signed in: nothing of anybody else's stays.
  static Future<void> removeOtherUids(String uid) => _removeWhere((k) => _uidOf(k) != uid);

  static Future<void> clear() => _removeWhere((_) => true);

  static Future<void> _removeWhere(bool Function(String key) test) async {
    final keys = {..._mem.keys, ...?_box?.keys.cast<String>()}.where(test).toList();
    for (final k in keys) {
      _forget(k);
    }
    if (keys.isEmpty) return;
    try {
      await _box?.deleteAll(keys);
    } catch (e) {
      debugPrint('[chat] delete failed: $e');
    }
  }

  @visibleForTesting
  static int get persistedCount => _box?.length ?? 0;

  @visibleForTesting
  static String? persistedRaw(String uid, String cid) => _box?.get(_key(uid, cid));

  /// Forget memory, keep the disk: what a cold start sees.
  @visibleForTesting
  static void dropMemoryForTest() {
    _mem.clear();
    _persistedSig.clear();
    _persistedAt.clear();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'config.dart';

/// One saved answer, as [OfflineCache.entry] returns it.
class SavedEntry {
  SavedEntry._(this.key, this.body, this.etag, this.savedAt, this.validatedAt, this.pinned, this._now);

  final String key;

  /// The response body exactly as the server sent it.
  final String body;
  final String? etag;

  /// When the body was stored (ms since epoch).
  final int savedAt;

  /// When the server last confirmed it, by a 200 or a 304 (ms since epoch).
  final int validatedAt;
  final bool pinned;
  final int _now;

  /// How long since the server last confirmed it. Floored at zero: a phone's
  /// clock can go backwards, and a negative age would read as "very fresh".
  Duration get age => Duration(milliseconds: math.max(0, _now - validatedAt));
}

class _Meta {
  _Meta(this.s, this.t, this.e, this.p);

  final int s;
  final int t;
  final String? e;
  final bool p;

  String encode() => jsonEncode({'s': s, 't': t, 'e': e, 'p': p ? 1 : 0});

  static _Meta? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      return _Meta(
        (m['s'] as num?)?.toInt() ?? 0,
        (m['t'] as num?)?.toInt() ?? 0,
        m['e'] as String?,
        m['p'] == 1,
      );
    } catch (_) {
      return null;
    }
  }
}

/// What a write (or a sign-out) took away while reads were in flight. A read
/// that started before it and covers the same ground must not save its answer:
/// the answer may describe the world before the write.
class _Tomb {
  _Tomb(this.epoch, this.atMs, this.uids, this.exact, this.prefixes, this.all);

  final int epoch;
  final int atMs;
  final Set<String>? uids;
  final Set<String> exact;
  final List<String> prefixes;
  final bool all;

  bool matches(String uid, String path) {
    final u = uids;
    if (u != null && !u.contains(uid)) return false;
    if (all) return true;
    return OfflineCache._pathMatches(path, exact, prefixes);
  }
}

/// The last answer to the app's reads, kept on the device.
///
/// Two jobs. Saved-first: a screen paints what it showed last time at once,
/// and the read that follows only repaints when something changed (often a
/// 304 with no body, see [ApiClient.read]). And offline: a read that cannot
/// reach the server is answered from here, so a bus with no signal does not
/// turn the app into an empty shell.
///
/// Writes are never kept and never queued: a purchase or a message replayed
/// later, from a stale screen, is worse than being told it did not go. After a
/// write, [CacheRules] patches, marks stale or drops the saved reads it
/// touched, so a saved copy never brings back what the person just changed.
///
/// Every key starts with the account it belongs to, so one person's inbox is
/// never shown to another who signs in on the same phone; a different account
/// signing in also wipes the previous one's entries ([adopt]), and sign-out
/// empties everything ([clear]).
///
/// Two boxes: bodies, and a small meta record per body (when saved, when last
/// confirmed, the ETag, pinned). Bounded by count and by size; pruned oldest
/// first, unpinned before pinned. Only lib/api uses this class.
abstract final class OfflineCache {
  static const String _bodyBox = 'api_body_v2';
  static const String _metaBox = 'api_meta_v2';
  static const String _infoKey = '__meta';
  static const String _goneKey = '__gone';

  static const int maxEntries = 500;
  static const int maxChars = 3000000;

  /// One answer larger than this is not kept: it would push out dozens of
  /// small ones that are opened far more often.
  static const int maxEntryChars = 400000;

  static const int _goneCap = 300;
  static const Duration _goneTtl = Duration(days: 30);
  static const Duration _touchEvery = Duration(minutes: 10);
  static const Duration _tombTtl = Duration(minutes: 2);

  static Box<String>? _body;
  static Box<String>? _meta;
  static String _base = AppConfig.apiBaseUrl;
  static String? _lastUid;
  static int _chars = 0;
  static int _maxEntries = maxEntries;
  static int _maxChars = maxChars;
  static bool _web = kIsWeb;
  static int Function() _clock = _wallClock;
  static int _epoch = 0;
  static int _generation = 0;
  static final List<_Tomb> _tombs = [];
  static final Map<String, int> _validated = {};
  static final Map<String, int> _gone = {};
  static Timer? _goneTimer;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  /// True while the screen in front of the person is showing saved answers
  /// because the last read could not reach the API. Cleared by the next read
  /// that does. Kept for compatibility; screens use [SavedReason] instead.
  static final ValueNotifier<bool> showingSaved = ValueNotifier(false);

  static bool get available => _body != null && _meta != null;

  /// Bumped by every remove, drop, stale, patch, clear and new session.
  static int get epoch => _epoch;

  /// Bumped on every account switch and sign-out. A read that started in an
  /// older generation belongs to another account.
  static int get generation => _generation;

  /// The account the store last belonged to.
  static String? get lastUid => _lastUid;

  static Future<void> init() async {
    final sw = Stopwatch()..start();
    try {
      await Hive.initFlutter();
      await _open(AppConfig.apiBaseUrl);
      if (kDebugMode) {
        debugPrint('[offline] open ${sw.elapsedMilliseconds}ms, ${_body!.length} entries, $_chars chars');
      }
    } catch (e) {
      // Private browsing, a full disk, a corrupt file: the app works exactly as
      // it did before this existed, just without the saved copies.
      debugPrint('[offline] cache unavailable: $e');
      _body = null;
      _meta = null;
    }
  }

  @visibleForTesting
  static Future<void> initForTest(String dir,
      {int? maxEntries, int? maxChars, int Function()? clock, bool? web, String? base}) async {
    await closeForTest();
    _maxEntries = maxEntries ?? OfflineCache.maxEntries;
    _maxChars = maxChars ?? OfflineCache.maxChars;
    _clock = clock ?? _wallClock;
    _web = web ?? kIsWeb;
    _epoch = 0;
    _generation = 0;
    Hive.init(dir);
    await _open(base ?? AppConfig.apiBaseUrl);
  }

  @visibleForTesting
  static Future<void> closeForTest() async {
    _goneTimer?.cancel();
    _goneTimer = null;
    _tombs.clear();
    _validated.clear();
    _gone.clear();
    _lastUid = null;
    _chars = 0;
    showingSaved.value = false;
    try {
      await _body?.close();
      await _meta?.close();
    } catch (_) {}
    _body = null;
    _meta = null;
  }

  static Future<void> _open(String base) async {
    _base = base;
    final b = await Hive.openBox<String>(_bodyBox);
    final m = await Hive.openBox<String>(_metaBox);
    final info = _decodeMap(m.get(_infoKey));
    if (info == null || info['v'] != 2 || info['base'] != base) {
      // A different API (a dev build pointed at staging, say) or a layout this
      // build does not know: none of it can be trusted.
      await b.clear();
      await m.clear();
      _lastUid = null;
      await m.put(_infoKey, jsonEncode({'v': 2, 'base': base, 'lastUid': null}));
    } else {
      _lastUid = info['lastUid'] as String?;
    }
    final orphanBodies = [for (final k in b.keys.cast<String>()) if (!m.containsKey(k)) k];
    final orphanMetas = [
      for (final k in m.keys.cast<String>()) if (!_reserved(k) && !b.containsKey(k)) k,
    ];
    if (orphanBodies.isNotEmpty) await b.deleteAll(orphanBodies);
    if (orphanMetas.isNotEmpty) await m.deleteAll(orphanMetas);
    var chars = 0;
    for (final v in b.values) {
      chars += v.length;
    }
    _chars = chars;
    _gone.clear();
    final gone = _decodeMap(m.get(_goneKey));
    if (gone != null) {
      final rows = [
        for (final e in gone.entries)
          if (e.value is num) MapEntry(e.key, (e.value as num).toInt()),
      ]..sort((x, y) => x.value.compareTo(y.value));
      for (final e in rows) {
        _gone[e.key] = e.value;
      }
    }
    _body = b;
    _meta = m;
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static bool _reserved(String key) => key.startsWith('__');

  // ── Keys ────────────────────────────────────────────────────────────────

  /// `uid|path|qhash`: the account and the path in clear (so a write can find
  /// what it touched), the query as a short hash (so a long French search
  /// cannot push a key past Hive's 255-byte limit). Null when the key would
  /// still be too long; that read is simply not saved. hive_ce checks the
  /// limit only in an assert and writes the length into one byte, so a longer
  /// key would corrupt the file in a release build.
  static String? keyFor(String? uid, String path, Map<String, String> query) {
    var qhash = '';
    if (query.isNotEmpty) {
      final keys = query.keys.toList()..sort();
      final q = [
        for (final k in keys) '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(query[k]!)}',
      ].join('&');
      qhash = sha1.convert(utf8.encode(q)).toString().substring(0, 16);
    }
    final key = '${uid ?? 'anon'}|$path|$qhash';
    if (utf8.encode(key).length > 255) return null;
    return key;
  }

  static (String, String) _parts(String key) {
    final a = key.indexOf('|');
    final b = key.lastIndexOf('|');
    if (a < 0 || b <= a) return (key, '');
    return (key.substring(0, a), key.substring(a + 1, b));
  }

  static bool _pathMatches(String path, Iterable<String> exact, List<String> prefixes) {
    for (final e in exact) {
      if (path == e) return true;
    }
    for (final p in prefixes) {
      if (path == p || path.startsWith('$p/')) return true;
    }
    return false;
  }

  // ── Reading and saving ──────────────────────────────────────────────────

  static _Meta? _readMeta(String key) => _Meta.decode(_meta?.get(key));

  /// The saved answer for [key], synchronously, or null.
  static SavedEntry? entry(String key) {
    final b = _body;
    if (b == null || _meta == null) return null;
    try {
      final body = b.get(key);
      if (body == null) return null;
      final meta = _readMeta(key);
      if (meta == null) return null;
      final validated = math.max(meta.t, _validated[key] ?? 0);
      return SavedEntry._(key, body, meta.e, meta.s, validated, meta.p, _clock());
    } catch (_) {
      return null;
    }
  }

  /// Keep [body] for [key]. A no-op when something that covers [key] was
  /// removed, dropped, patched or cleared after [startedEpoch]: the body may
  /// be from before that change.
  static Future<void> put(String key, String body,
      {String? etag, bool pinned = false, required int startedEpoch}) async {
    final b = _body;
    final m = _meta;
    if (b == null || m == null) return;
    if (supersededSince(key, startedEpoch)) return;
    if (body.length > maxEntryChars) {
      // Not kept, and an older copy must not stand in for it.
      if (b.containsKey(key)) await _deleteKeys([key]);
      return;
    }
    final now = _clock();
    try {
      final old = b.get(key);
      _chars += body.length - (old?.length ?? 0);
      _validated[key] = now;
      // Both writes start before anything is awaited, so entry() sees the new
      // body straight away.
      await Future.wait([
        b.put(key, body),
        m.put(key, _Meta(now, now, etag, pinned).encode()),
      ]);
    } catch (e) {
      debugPrint('[offline] save failed: $e');
      return;
    }
    // Closed or cleared meanwhile (tests, a failed open): nothing to prune.
    if (!identical(_body, b) || !b.isOpen) return;
    if (b.length > _maxEntries || _chars > _maxChars) await _prune();
  }

  /// The server confirmed the saved copy (a 304). Always moves the in-memory
  /// "last confirmed" time; writes to disk only when the ETag changed or the
  /// stored time is more than ten minutes old, so a 304 costs no disk write.
  static Future<void> touch(String key, {String? etag, required int startedEpoch}) async {
    final m = _meta;
    if (m == null) return;
    if (supersededSince(key, startedEpoch)) return;
    final meta = _readMeta(key);
    if (meta == null) return;
    final now = _clock();
    _validated[key] = now;
    final etagChanged = etag != null && etag != meta.e;
    if (!etagChanged && now - meta.t <= _touchEvery.inMilliseconds) return;
    try {
      await m.put(key, _Meta(meta.s, now, etag ?? meta.e, meta.p).encode());
    } catch (e) {
      debugPrint('[offline] touch failed: $e');
    }
  }

  /// Whether a remove/drop/stale/patch/clear that covers [key] happened after
  /// [startedEpoch].
  static bool supersededSince(String key, int startedEpoch) {
    if (_epoch <= startedEpoch) return false;
    final (uid, path) = _parts(key);
    for (final t in _tombs) {
      if (t.epoch > startedEpoch && t.matches(uid, path)) return true;
    }
    return false;
  }

  /// Records the tombstone and bumps [epoch]. Always called before the first
  /// await of the method that calls it, so a caller may fire that method
  /// without awaiting and still be sure no older read saves over it.
  static void _tomb({Set<String>? uids, Iterable<String> exact = const [],
      List<String> prefixes = const [], bool all = false}) {
    _epoch++;
    final now = _clock();
    _tombs.removeWhere((t) => (now - t.atMs).abs() > _tombTtl.inMilliseconds);
    _tombs.add(_Tomb(_epoch, now, uids == null ? null : Set.of(uids), Set.of(exact), List.of(prefixes), all));
  }

  static List<String> _matching({Set<String>? uids, Iterable<String> exact = const [],
      List<String> prefixes = const []}) {
    final b = _body;
    if (b == null) return const [];
    return [
      for (final k in b.keys.cast<String>())
        if (_keyMatches(k, uids, exact, prefixes)) k,
    ];
  }

  static bool _keyMatches(String k, Set<String>? uids, Iterable<String> exact, List<String> prefixes) {
    final (u, p) = _parts(k);
    if (uids != null && !uids.contains(u)) return false;
    return _pathMatches(p, exact, prefixes);
  }

  static Future<void> _deleteKeys(List<String> keys) async {
    final b = _body;
    final m = _meta;
    if (b == null || m == null || keys.isEmpty) return;
    try {
      for (final k in keys) {
        _chars -= b.get(k)?.length ?? 0;
        _validated.remove(k);
      }
      if (_chars < 0) _chars = 0;
      await Future.wait([b.deleteAll(keys), m.deleteAll(keys)]);
    } catch (e) {
      debugPrint('[offline] delete failed: $e');
    }
  }

  static Future<void> remove(String key) async {
    final (uid, path) = _parts(key);
    _tomb(uids: {uid}, exact: [path]);
    await _deleteKeys([key]);
  }

  /// Remove every saved answer whose path is in [exact] (any query) or under
  /// one of [prefixes] (`p` itself and `p/…`), for [uids] (null: every
  /// account). With [bodyContains], only the bodies that contain it.
  static Future<void> drop({Set<String>? uids, List<String> exact = const [],
      List<String> prefixes = const [], String? bodyContains}) async {
    _tomb(uids: uids, exact: exact, prefixes: prefixes);
    final b = _body;
    if (b == null) return;
    var keys = _matching(uids: uids, exact: exact, prefixes: prefixes);
    if (bodyContains != null) {
      keys = [for (final k in keys) if (b.get(k)?.contains(bodyContains) ?? false) k];
    }
    await _deleteKeys(keys);
  }

  /// Keep the bodies but forget their ETags, so the next read is a full 200
  /// instead of a 304 confirming a copy that is now out of date.
  static Future<void> stale({Set<String>? uids, List<String> exact = const [],
      List<String> prefixes = const []}) async {
    _tomb(uids: uids, exact: exact, prefixes: prefixes);
    final m = _meta;
    if (m == null) return;
    final writes = <Future<void>>[];
    for (final k in _matching(uids: uids, exact: exact, prefixes: prefixes)) {
      final meta = _readMeta(k);
      if (meta == null || meta.e == null) continue;
      writes.add(m.put(k, _Meta(meta.s, meta.t, null, meta.p).encode()));
    }
    try {
      await Future.wait(writes);
    } catch (e) {
      debugPrint('[offline] stale failed: $e');
    }
  }

  /// Rewrite every saved answer of exactly [path] (any query) through [edit],
  /// which gets the decoded JSON. Returning null removes the entry; returning
  /// something that encodes to the same JSON leaves it alone. A rewritten
  /// entry loses its ETag (the server never sent that body) and keeps its
  /// "last confirmed" time.
  static Future<void> patch(String path, Object? Function(Object? json) edit, {Set<String>? uids}) async {
    _tomb(uids: uids, exact: [path]);
    final b = _body;
    final m = _meta;
    if (b == null || m == null) return;
    final removals = <String>[];
    final writes = <Future<void>>[];
    for (final k in _matching(uids: uids, exact: [path])) {
      final raw = b.get(k);
      final meta = _readMeta(k);
      if (raw == null || meta == null) continue;
      Object? out;
      try {
        out = edit(jsonDecode(raw));
      } catch (e) {
        debugPrint('[offline] patch of $path failed: $e');
        removals.add(k);
        continue;
      }
      if (out == null) {
        removals.add(k);
        continue;
      }
      final encoded = jsonEncode(out);
      if (encoded == raw) continue;
      _chars += encoded.length - raw.length;
      writes.add(b.put(k, encoded));
      writes.add(m.put(k, _Meta(meta.s, meta.t, null, meta.p).encode()));
    }
    writes.add(_deleteKeys(removals));
    try {
      await Future.wait(writes);
    } catch (e) {
      debugPrint('[offline] patch failed: $e');
    }
  }

  static Future<void> _prune() async {
    final b = _body;
    if (b == null || !b.isOpen) return;
    final rows = <({String key, bool pinned, int t, int len})>[];
    for (final k in b.keys.cast<String>()) {
      final meta = _readMeta(k);
      rows.add((
        key: k,
        pinned: meta?.p ?? false,
        t: math.max(meta?.t ?? 0, _validated[k] ?? 0),
        len: b.get(k)?.length ?? 0,
      ));
    }
    rows.sort((x, y) => x.pinned != y.pinned ? (x.pinned ? 1 : -1) : x.t.compareTo(y.t));
    final targetN = (_maxEntries * 4) ~/ 5;
    final targetC = (_maxChars * 4) ~/ 5;
    var n = rows.length;
    var c = _chars;
    final drop = <String>[];
    for (final r in rows) {
      if (n <= targetN && c <= targetC) break;
      drop.add(r.key);
      n--;
      c -= r.len;
    }
    await _deleteKeys(drop);
  }

  // ── Listings the network said are gone ──────────────────────────────────

  /// Remember that the server said this listing is sold, removed or deleted,
  /// so no saved feed or favourite shows it as live again.
  static void markGone(String listingId) {
    if (listingId.isEmpty) return;
    _gone.remove(listingId);
    _gone[listingId] = _clock();
    while (_gone.length > _goneCap) {
      _gone.remove(_gone.keys.first);
    }
    _goneDirty();
  }

  /// The server showed it as active again (relisted).
  static void unGone(String listingId) {
    if (_gone.remove(listingId) != null) _goneDirty();
  }

  static bool isGone(String listingId) {
    final at = _gone[listingId];
    if (at == null) return false;
    if (_clock() - at > _goneTtl.inMilliseconds) {
      _gone.remove(listingId);
      _goneDirty();
      return false;
    }
    return true;
  }

  static void _goneDirty() {
    _goneTimer ??= Timer(const Duration(seconds: 2), () {
      _goneTimer = null;
      unawaited(flushGone());
    });
  }

  @visibleForTesting
  static Future<void> flushGone() async {
    _goneTimer?.cancel();
    _goneTimer = null;
    final m = _meta;
    if (m == null) return;
    try {
      await m.put(_goneKey, jsonEncode(_gone));
    } catch (e) {
      debugPrint('[offline] gone save failed: $e');
    }
  }

  // ── Accounts ────────────────────────────────────────────────────────────

  static Future<void> _writeInfo() async {
    try {
      await _meta?.put(_infoKey, jsonEncode({'v': 2, 'base': _base, 'lastUid': _lastUid}));
    } catch (e) {
      debugPrint('[offline] meta save failed: $e');
    }
  }

  /// The store now belongs to [uid]. A different account signing in wipes
  /// every other account's entries (shared entries, `anon`, stay); on web,
  /// signing out (or a session expiring) wipes every account's entries,
  /// because a browser is more often shared than a phone. Returns the
  /// account the store belonged to before.
  static Future<String?> adopt(String? uid) async {
    final prev = _lastUid;
    final b = _body;
    if (b != null) {
      List<String> keys = const [];
      if (uid != null && uid != prev) {
        keys = [
          for (final k in b.keys.cast<String>())
            if (_parts(k).$1 != uid && _parts(k).$1 != 'anon') k,
        ];
      } else if (uid == null && _web) {
        keys = [for (final k in b.keys.cast<String>()) if (_parts(k).$1 != 'anon') k];
      }
      await _deleteKeys(keys);
    }
    if (uid != null && uid != prev) {
      _lastUid = uid;
      await _writeInfo();
    }
    return prev;
  }

  /// The signed-in account changed. No read that started before this can
  /// save, and memory-side callers can tell their results are stale.
  static Future<String?> newSession(String? uid) {
    _generation++;
    _tomb(all: true);
    return adopt(uid);
  }

  /// Everything, for sign-out.
  static Future<void> clear() async {
    _generation++;
    _tomb(all: true);
    showingSaved.value = false;
    _validated.clear();
    _gone.clear();
    _goneTimer?.cancel();
    _goneTimer = null;
    _lastUid = null;
    final b = _body;
    final m = _meta;
    if (b == null || m == null) return;
    try {
      final keys = b.keys.cast<String>().toList();
      final metas = [for (final k in m.keys.cast<String>()) if (!_reserved(k)) k];
      _chars = 0;
      // deleteAll, not clear(): Hive's clear() empties memory only after the
      // disk, so a read in between would still see the old answers.
      await Future.wait([
        b.deleteAll(keys),
        m.deleteAll([...metas, _goneKey]),
        _writeInfo(),
      ]);
    } catch (e) {
      debugPrint('[offline] clear failed: $e');
    }
  }

  // ── For tests ───────────────────────────────────────────────────────────

  @visibleForTesting
  static int get chars => _chars;

  @visibleForTesting
  static int get count => _body?.length ?? 0;

  @visibleForTesting
  static List<String> get keys => _body?.keys.cast<String>().toList() ?? const [];

  /// The "last confirmed" time as stored on disk, ignoring memory.
  @visibleForTesting
  static int? persistedValidatedAt(String key) => _readMeta(key)?.t;

  @visibleForTesting
  static bool hasReserved(String key) => _meta?.containsKey(key) ?? false;
}

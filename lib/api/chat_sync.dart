// How a chat on this device catches up with the server, as pure functions:
// no Flutter, no Hive, no dart:io, so every rule is testable on its own and the
// same code runs on web. ChatStore keeps the result; ChatRepository.syncThread
// runs the algorithm.
//
// The idea: a thread keeps its newest 100 server messages and a cursor (the
// raw created_at of the newest one). Opening the thread asks only for what is
// newer than the cursor (`after`), and the server says how many messages the
// caller can see in total (`sync.visible_count`). If the count does not add
// up, something changed further back (a message held, released or removed)
// and the thread is fetched in full instead.

/// Debug QA hook (QA H). Rule 4's re-sign window: attachment URLs are signed
/// for about an hour, so a thread holding attachments is fetched in full
/// (which re-signs them) once its last full fetch is older than this.
const int chatResignMinutes = int.fromEnvironment('CHAT_RESIGN_MINUTES', defaultValue: 50);

const int _maxItems = 100;
const int _dayMs = 24 * 60 * 60 * 1000;

final RegExp _ts = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?\s*(Z|z|[+-]\d{2}(?::?\d{2})?)?$',
);

/// µs since epoch for a PostgREST or realtime timestamptz: 'T' or ' '
/// separator, 0–6 fraction digits (more are cut), offset Z / ±HH / ±HHMM /
/// ±HH:MM (none reads as UTC). Whole seconds come from DateTime.utc (no
/// fraction); then ×1e6 plus the fraction padded to 6 digits, minus the
/// offset. Values stay below 2^53 and no bit operations are used, so dart2js
/// gets the same answer. Returns 0 for an unparseable value.
///
/// Never rebuild a cursor from a DateTime: DateTime keeps microseconds on the
/// VM only, and a cursor that lost them would skip or repeat messages.
int chatTimeMicros(String raw) {
  final m = _ts.firstMatch(raw.trim());
  if (m == null) return 0;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final h = int.parse(m.group(4)!);
  final mi = int.parse(m.group(5)!);
  final s = int.parse(m.group(6)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 60) return 0;
  final seconds = DateTime.utc(y, mo, d, h, mi, s).millisecondsSinceEpoch ~/ 1000;
  var frac = m.group(7) ?? '';
  if (frac.length > 6) frac = frac.substring(0, 6);
  final micros = frac.isEmpty ? 0 : int.parse(frac.padRight(6, '0'));
  var offsetSeconds = 0;
  final off = m.group(8);
  if (off != null && off != 'Z' && off != 'z') {
    final sign = off.startsWith('-') ? -1 : 1;
    final digits = off.substring(1).replaceAll(':', '');
    final oh = int.parse(digits.substring(0, 2));
    final om = digits.length >= 4 ? int.parse(digits.substring(2, 4)) : 0;
    offsetSeconds = sign * (oh * 3600 + om * 60);
  }
  return (seconds - offsetSeconds) * 1000000 + micros;
}

int _micros(Object? raw) => raw == null ? 0 : chatTimeMicros(raw.toString());

/// Oldest first: created_at, then id ascending, so equal timestamps still
/// have one order on every device.
int compareMessages(Map a, Map b) {
  final t = _micros(a['created_at']).compareTo(_micros(b['created_at']));
  if (t != 0) return t;
  return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
}

String _modStatus(Map m) =>
    m['moderation_status']?.toString() ?? (m['moderation'] as Map?)?['status']?.toString() ?? 'visible';

bool _appealed(Map m) => (m['moderation'] as Map?)?['appealed'] == true;

/// What a repaint depends on, per message: a new id, a read tick, a
/// moderation decision, an appeal, a moved or stopped location, an attachment
/// URL appearing or going.
String signature(List<Map<String, dynamic>> items) {
  final b = StringBuffer();
  for (final m in items) {
    final loc = m['location'] is Map ? m['location'] as Map : null;
    b
      ..write(m['id'])
      ..write('|')
      ..write(m['read_at'])
      ..write('|')
      ..write(_modStatus(m))
      ..write('|')
      ..write(_appealed(m))
      ..write('|')
      ..write(loc?['updated_at'])
      ..write('|')
      ..write(loc?['stopped_at'])
      ..write('|')
      ..write(m['attachment_url'] != null)
      ..write('\n');
  }
  return b.toString();
}

/// One conversation as kept on the device.
class StoredThread {
  const StoredThread({
    this.cursor,
    this.count,
    this.syncedAt = 0,
    this.lastFullAt = 0,
    this.signedAt = 0,
    this.openedAt = 0,
    this.items = const [],
  });

  /// The raw created_at of the newest item that came from a GET. Kept as the
  /// server wrote it, microseconds and all.
  final String? cursor;

  /// What the server last said the caller can see in this thread. Null forces
  /// a full fetch (an old server, or a thread only ever written locally).
  final int? count;

  /// Last successful sync, last full fetch, last time attachment URLs were
  /// signed, last time the thread was opened (ms since epoch).
  final int syncedAt;
  final int lastFullAt;
  final int signedAt;
  final int openedAt;

  /// Raw server message maps, oldest first, at most 100.
  final List<Map<String, dynamic>> items;

  static const Object _keep = Object();

  StoredThread copyWith({
    Object? cursor = _keep,
    Object? count = _keep,
    int? syncedAt,
    int? lastFullAt,
    int? signedAt,
    int? openedAt,
    List<Map<String, dynamic>>? items,
  }) =>
      StoredThread(
        cursor: identical(cursor, _keep) ? this.cursor : cursor as String?,
        count: identical(count, _keep) ? this.count : count as int?,
        syncedAt: syncedAt ?? this.syncedAt,
        lastFullAt: lastFullAt ?? this.lastFullAt,
        signedAt: signedAt ?? this.signedAt,
        openedAt: openedAt ?? this.openedAt,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        't': syncedAt,
        'f': lastFullAt,
        's': signedAt,
        'o': openedAt,
        'c': cursor,
        'n': count,
        'i': items,
      };

  static StoredThread? fromJson(Object? json) {
    if (json is! Map || json['v'] != 1) return null;
    final raw = json['i'];
    return StoredThread(
      cursor: json['c'] as String?,
      count: (json['n'] as num?)?.toInt(),
      syncedAt: (json['t'] as num?)?.toInt() ?? 0,
      lastFullAt: (json['f'] as num?)?.toInt() ?? 0,
      signedAt: (json['s'] as num?)?.toInt() ?? 0,
      openedAt: (json['o'] as num?)?.toInt() ?? 0,
      items: raw is List
          ? [for (final m in raw.whereType<Map>()) Map<String, dynamic>.from(m)]
          : const [],
    );
  }
}

/// One answer from GET /conversations/:id/messages.
class ChatPage {
  const ChatPage({required this.items, this.nextBefore, this.visibleCount, this.peerReadThrough});

  final List<Map<String, dynamic>> items;
  final String? nextBefore;

  /// From the `sync` block. Null against a server that does not send it.
  final int? visibleCount;
  final String? peerReadThrough;

  factory ChatPage.fromJson(Map<String, dynamic> json) {
    final sync = json['sync'] is Map ? json['sync'] as Map : null;
    return ChatPage(
      items: [
        for (final m in (json['items'] as List? ?? const []).whereType<Map>())
          Map<String, dynamic>.from(m),
      ],
      nextBefore: ((json['page'] as Map?)?['next_before'])?.toString(),
      visibleCount: (sync?['visible_count'] as num?)?.toInt(),
      peerReadThrough: sync?['peer_read_through']?.toString(),
    );
  }
}

enum ChatFetch { full, incremental }

class MergeOutcome {
  const MergeOutcome({
    this.thread,
    this.needFull = false,
    this.retryIncremental = false,
    this.changed = false,
    this.added = 0,
    this.newestIsMine = false,
  });

  /// The new state, or null when [needFull] or [retryIncremental].
  final StoredThread? thread;
  final bool needFull;
  final bool retryIncremental;
  final bool changed;
  final int added;
  final bool newestIsMine;
}

List<Map<String, dynamic>> _ordered(Iterable<Map<String, dynamic>> items) {
  final list = items.toList()..sort(compareMessages);
  return list.length > _maxItems ? list.sublist(list.length - _maxItems) : list;
}

String? _newestRaw(List<Map<String, dynamic>> items) {
  Map<String, dynamic>? newest;
  for (final m in items) {
    if (_micros(m['created_at']) == 0) continue;
    if (newest == null || compareMessages(m, newest) > 0) newest = m;
  }
  return newest?['created_at']?.toString();
}

/// Full or incremental. Full when any of these holds:
/// 1. nothing stored, or no cursor or count;
/// 2. the last sync is more than 3 days old;
/// 3. the last full fetch is more than 24 h old (bounds drift the count
///    cannot see);
/// 4. an item has an attachment and its URL was signed longer ago than
///    [chatResignMinutes];
/// 5. one of my items is held, or rejected and appealed within 14 days (a
///    decision moves it without a new message);
/// 6. an item is a running live share.
ChatFetch chooseFetch(StoredThread? s, {required String myUid, required int nowMs}) {
  if (s == null || s.cursor == null || s.count == null) return ChatFetch.full;
  if (nowMs - s.syncedAt > 3 * _dayMs) return ChatFetch.full;
  if (nowMs - s.lastFullAt > _dayMs) return ChatFetch.full;
  final resignMs = chatResignMinutes * 60 * 1000;
  final nowMicros = nowMs * 1000;
  for (final m in s.items) {
    final path = m['attachment_path']?.toString() ?? '';
    if (path.isNotEmpty && nowMs - s.signedAt > resignMs) return ChatFetch.full;
    if (m['sender_id']?.toString() == myUid) {
      final status = _modStatus(m);
      if (status == 'held') return ChatFetch.full;
      if (status == 'rejected' && _appealed(m)) {
        final created = _micros(m['created_at']);
        if (nowMicros - created <= 14 * _dayMs * 1000) return ChatFetch.full;
      }
    }
    final loc = m['location'] is Map ? m['location'] as Map : null;
    if (loc != null && loc['mode']?.toString() == 'live' && loc['stopped_at'] == null) {
      final ends = _micros(loc['expires_at']);
      if (ends > nowMicros) return ChatFetch.full;
    }
  }
  return ChatFetch.incremental;
}

/// The thread is what the page says. Its window, cursor and count replace
/// whatever was stored.
StoredThread applyFull(ChatPage p, {required int nowMs, StoredThread? previous}) {
  final items = _ordered(p.items);
  return StoredThread(
    cursor: _newestRaw(items),
    count: p.visibleCount,
    syncedAt: nowMs,
    lastFullAt: nowMs,
    signedAt: nowMs,
    openedAt: previous?.openedAt ?? nowMs,
    items: items,
  );
}

MergeOutcome _replaced(StoredThread s, ChatPage p, String myUid, int nowMs) {
  final next = applyFull(p, nowMs: nowMs, previous: s);
  final before = {for (final m in s.items) m['id']?.toString()};
  final added = [for (final m in next.items) if (!before.contains(m['id']?.toString())) m];
  return MergeOutcome(
    thread: next,
    changed: signature(s.items) != signature(next.items),
    added: added.length,
    newestIsMine: added.isNotEmpty && added.last['sender_id']?.toString() == myUid,
  );
}

/// Fold an `after` page into what is stored.
MergeOutcome mergeIncremental(StoredThread s, ChatPage p,
    {required String myUid, required int nowMs, required bool retried}) {
  // An old server ignored `after` and sent the newest page; or more new
  // messages exist than one page holds. Either way the page is the window.
  if (p.visibleCount == null || p.nextBefore != null) return _replaced(s, p, myUid, nowMs);

  final byId = <String, Map<String, dynamic>>{
    for (final m in s.items) m['id']?.toString() ?? '': m,
  };
  final added = <Map<String, dynamic>>[];
  for (final m in p.items) {
    final id = m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    if (!byId.containsKey(id)) added.add(m);
    byId[id] = m;
  }
  var items = _ordered(byId.values);

  final prt = p.peerReadThrough;
  if (prt != null) {
    final through = chatTimeMicros(prt);
    items = [
      for (final m in items)
        if (m['sender_id']?.toString() == myUid && m['read_at'] == null && _micros(m['created_at']) <= through)
          {...m, 'read_at': prt}
        else
          m,
    ];
  }

  final known = s.count;
  if (known == null) return const MergeOutcome(needFull: true);
  final expected = known + added.length;
  if (p.visibleCount! < expected) return const MergeOutcome(needFull: true);
  if (p.visibleCount! > expected) {
    return retried ? const MergeOutcome(needFull: true) : const MergeOutcome(retryIncremental: true);
  }

  var cursor = s.cursor;
  final newest = _newestRaw(p.items);
  if (newest != null && (cursor == null || chatTimeMicros(newest) > chatTimeMicros(cursor))) cursor = newest;
  added.sort(compareMessages);
  return MergeOutcome(
    thread: s.copyWith(cursor: cursor, count: p.visibleCount, syncedAt: nowMs, items: items),
    changed: signature(s.items) != signature(items),
    added: added.length,
    newestIsMine: added.isNotEmpty && added.last['sender_id']?.toString() == myUid,
  );
}

/// A message this device just sent (the server's own row). Painted at once;
/// the cursor never moves for it, or a peer message committed a moment
/// earlier would be skipped for good.
StoredThread upsertLocal(StoredThread? s, Map<String, dynamic> serverMessage, {int? nowMs}) {
  final id = serverMessage['id']?.toString() ?? '';
  if (id.isEmpty || id.startsWith('local:')) return s ?? const StoredThread();
  if (s == null) {
    return StoredThread(items: [serverMessage], signedAt: nowMs ?? 0, openedAt: nowMs ?? 0);
  }
  if (s.items.any((m) => m['id']?.toString() == id)) return s;
  final c = s.count;
  return s.copyWith(
    items: _ordered([...s.items, serverMessage]),
    // My own messages count under RLS even while held.
    count: c == null ? null : c + 1,
  );
}

/// Edit the stored messages [where] matches. Each one is copied first, so a
/// map another reader holds is never changed under it.
StoredThread patchWhere(StoredThread s, bool Function(Map<String, dynamic>) where,
    void Function(Map<String, dynamic>) edit) {
  var hit = false;
  final items = <Map<String, dynamic>>[];
  for (final m in s.items) {
    if (where(m)) {
      final copy = _deepCopy(m);
      edit(copy);
      items.add(copy);
      hit = true;
    } else {
      items.add(m);
    }
  }
  return hit ? s.copyWith(items: items) : s;
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> m) => {
      for (final e in m.entries)
        e.key: e.value is Map
            ? _deepCopy(Map<String, dynamic>.from(e.value as Map))
            : e.value is List
                ? List.of(e.value as List)
                : e.value,
    };

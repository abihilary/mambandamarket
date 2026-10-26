import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/cache_rules.dart';
import 'package:mambandamarket/api/chat_sync.dart';

void main() {
  const me = 'me';
  const peer = 'peer';
  const min = 60 * 1000;
  const day = 24 * 60 * min;
  // 2026-10-25T09:00:00Z
  final now = DateTime.utc(2026, 10, 25, 9).millisecondsSinceEpoch;

  Map<String, dynamic> msg(String id, String at, {String sender = peer, Map<String, dynamic> extra = const {}}) =>
      {'id': id, 'sender_id': sender, 'created_at': at, 'body': id, 'read_at': null, ...extra};

  StoredThread thread(List<Map<String, dynamic>> items, {String? cursor, int? count, int? syncedAt, int? lastFullAt, int? signedAt}) =>
      StoredThread(
        cursor: cursor ?? (items.isEmpty ? null : items.last['created_at'] as String),
        count: count ?? items.length,
        syncedAt: syncedAt ?? now,
        lastFullAt: lastFullAt ?? now,
        signedAt: signedAt ?? now,
        openedAt: now,
        items: items,
      );

  group('chatTimeMicros', () {
    test('fractions, offsets and separators', () {
      final base = DateTime.utc(2026, 10, 25, 9, 14, 3).millisecondsSinceEpoch * 1000;
      expect(chatTimeMicros('2026-10-25T09:14:03Z'), base);
      expect(chatTimeMicros('2026-10-25T09:14:03.1Z'), base + 100000);
      expect(chatTimeMicros('2026-10-25T09:14:03.123456Z'), base + 123456);
      expect(chatTimeMicros('2026-10-25 09:14:03.123456+00'), base + 123456);
      expect(chatTimeMicros('2026-10-25T09:14:03.123456+00:00'), base + 123456);
      expect(chatTimeMicros('2026-10-25T10:14:03.123456+0100'), base + 123456);
      expect(chatTimeMicros('2026-10-25T10:14:03.123456+01:00'), base + 123456);
      expect(chatTimeMicros('2026-10-25T08:14:03-01'), base);
      expect(chatTimeMicros('2026-10-25T09:14:03'), base);
    });

    test('equal instants in different spellings compare equal', () {
      expect(chatTimeMicros('2026-10-25 09:14:03.5+00'), chatTimeMicros('2026-10-25T10:14:03.500000+01:00'));
    });

    test('.2 sorts after .19', () {
      expect(chatTimeMicros('2026-10-25T09:14:03.2Z'), greaterThan(chatTimeMicros('2026-10-25T09:14:03.19Z')));
    });

    test('stays below 2^53 (exact on web) for any date the app will see', () {
      expect(chatTimeMicros('2200-12-31T23:59:59.999999+14:00'), lessThan(9007199254740992));
      expect(chatTimeMicros('2026-10-25T09:14:03.999999Z') % 1000000, 999999);
    });

    test('garbage is 0', () {
      expect(chatTimeMicros(''), 0);
      expect(chatTimeMicros('yesterday'), 0);
      expect(chatTimeMicros('2026-13-01T00:00:00Z'), 0);
    });
  });

  group('chooseFetch', () {
    ChatFetch choose(StoredThread? s) => chooseFetch(s, myUid: me, nowMs: now);
    final ok = thread([msg('m1', '2026-10-25T08:00:00Z')]);

    test('1. nothing stored, no cursor or no count', () {
      expect(choose(ok), ChatFetch.incremental);
      expect(choose(null), ChatFetch.full);
      expect(choose(ok.copyWith(cursor: null)), ChatFetch.full);
      expect(choose(ok.copyWith(count: null)), ChatFetch.full);
    });

    test('2. last sync older than 3 days', () {
      expect(choose(ok.copyWith(syncedAt: now - 3 * day - 1, lastFullAt: now)), ChatFetch.full);
      expect(choose(ok.copyWith(syncedAt: now - 2 * day)), ChatFetch.incremental);
    });

    test('3. last full fetch older than 24 h', () {
      expect(choose(ok.copyWith(lastFullAt: now - day - 1)), ChatFetch.full);
      expect(choose(ok.copyWith(lastFullAt: now - 23 * 60 * min)), ChatFetch.incremental);
    });

    test('4. attachments past the re-sign window', () {
      final withFile = thread([msg('m1', '2026-10-25T08:00:00Z', extra: {'attachment_path': 'u/x/a.jpg'})]);
      expect(choose(withFile.copyWith(signedAt: now - (chatResignMinutes + 1) * min)), ChatFetch.full);
      expect(choose(withFile.copyWith(signedAt: now - (chatResignMinutes - 1) * min)), ChatFetch.incremental);
      expect(choose(ok.copyWith(signedAt: now - 2 * day + 1)), ChatFetch.incremental);
    });

    test('5. my held, or recently appealed rejected, messages', () {
      expect(choose(thread([msg('m1', '2026-10-25T08:00:00Z', sender: me, extra: {'moderation_status': 'held'})])),
          ChatFetch.full);
      expect(choose(thread([msg('m1', '2026-10-25T08:00:00Z', sender: peer, extra: {'moderation_status': 'held'})])),
          ChatFetch.incremental);
      expect(
          choose(thread([
            msg('m1', '2026-10-20T08:00:00Z', sender: me, extra: {
              'moderation_status': 'rejected',
              'moderation': {'appealed': true},
            }),
          ])),
          ChatFetch.full);
      // Rejected and never appealed: nothing will move it.
      expect(choose(thread([msg('m1', '2026-10-20T08:00:00Z', sender: me, extra: {'moderation_status': 'rejected'})])),
          ChatFetch.incremental);
      // Appealed, but long ago.
      expect(
          choose(thread([
            msg('m1', '2026-09-01T08:00:00Z', sender: me, extra: {
              'moderation_status': 'rejected',
              'moderation': {'appealed': true},
            }),
          ])),
          ChatFetch.incremental);
    });

    test('6. a running live share', () {
      Map<String, dynamic> share(String expires, {String? stopped}) =>
          {'location': {'id': 's1', 'mode': 'live', 'expires_at': expires, 'stopped_at': stopped}};
      expect(choose(thread([msg('m1', '2026-10-25T08:30:00Z', extra: share('2026-10-25T09:30:00Z'))])), ChatFetch.full);
      expect(choose(thread([msg('m1', '2026-10-25T07:00:00Z', extra: share('2026-10-25T08:00:00Z'))])),
          ChatFetch.incremental);
      expect(
          choose(thread([
            msg('m1', '2026-10-25T08:30:00Z', extra: share('2026-10-25T09:30:00Z', stopped: '2026-10-25T08:40:00Z')),
          ])),
          ChatFetch.incremental);
    });
  });

  test('applyFull keeps the raw cursor and sets count and times', () {
    final s = applyFull(
      ChatPage(items: [
        msg('m2', '2026-10-25 09:14:03.123456+00'),
        msg('m1', '2026-10-25 09:14:02.5+00'),
      ], visibleCount: 7),
      nowMs: now,
    );
    expect(s.items.map((m) => m['id']), ['m1', 'm2']);
    expect(s.cursor, '2026-10-25 09:14:03.123456+00');
    expect(s.count, 7);
    expect([s.syncedAt, s.lastFullAt, s.signedAt], [now, now, now]);
    expect(applyFull(const ChatPage(items: []), nowMs: now).cursor, isNull);
  });

  group('mergeIncremental', () {
    final base = thread([
      msg('m1', '2026-10-25T08:00:00.000001Z', sender: me),
      msg('m2', '2026-10-25T08:00:01Z'),
    ]);

    MergeOutcome merge(StoredThread s, ChatPage p, {bool retried = false}) =>
        mergeIncremental(s, p, myUid: me, nowMs: now, retried: retried);

    test('overlap items dedupe and added counts only new ids', () {
      final o = merge(base, ChatPage(items: [msg('m2', '2026-10-25T08:00:01Z'), msg('m3', '2026-10-25T08:00:02Z')], visibleCount: 3));
      expect(o.needFull, isFalse);
      expect(o.added, 1);
      expect(o.changed, isTrue);
      expect(o.thread!.items.map((m) => m['id']), ['m1', 'm2', 'm3']);
      expect(o.thread!.count, 3);
      expect(o.thread!.cursor, '2026-10-25T08:00:02Z');
      expect(o.newestIsMine, isFalse);
    });

    test('the cursor never moves backwards', () {
      final o = merge(base, ChatPage(items: [msg('m0', '2026-10-25T07:59:59Z')], visibleCount: 3));
      expect(o.thread!.cursor, base.cursor);
    });

    test('order is by time, then id ascending, capped at 100', () {
      final many = [for (var i = 0; i < 100; i++) msg('a${i.toString().padLeft(3, '0')}', '2026-10-25T08:01:00Z')];
      final o = merge(base, ChatPage(items: many, visibleCount: 102));
      final ids = o.thread!.items.map((m) => m['id']).toList();
      expect(ids, hasLength(100));
      expect(ids.first, 'a000');
      expect(ids.last, 'a099');
    });

    test('peer_read_through marks only my older messages', () {
      final s = thread([
        msg('m1', '2026-10-25T08:00:00Z', sender: me),
        msg('m2', '2026-10-25T08:00:05Z', sender: me),
        msg('m3', '2026-10-25T08:00:01Z'),
      ]);
      final o = merge(s, const ChatPage(items: [], visibleCount: 3, peerReadThrough: '2026-10-25 08:00:02+00'));
      final byId = {for (final m in o.thread!.items) m['id']: m['read_at']};
      expect(byId['m1'], '2026-10-25 08:00:02+00');
      expect(byId['m2'], isNull);
      expect(byId['m3'], isNull);
      expect(o.changed, isTrue);
    });

    test('a lower count means something went: full', () {
      expect(merge(base, const ChatPage(items: [], visibleCount: 1)).needFull, isTrue);
    });

    test('a higher count retries once, then full', () {
      final first = merge(base, const ChatPage(items: [], visibleCount: 3));
      expect(first.retryIncremental, isTrue);
      expect(first.thread, isNull);
      expect(merge(base, const ChatPage(items: [], visibleCount: 3), retried: true).needFull, isTrue);
    });

    test('a gap (next_before) or an old server (no count) replaces the window', () {
      final gap = merge(base, ChatPage(items: [msg('m9', '2026-10-25T09:00:00Z')], nextBefore: 'x', visibleCount: 60));
      expect(gap.thread!.items.map((m) => m['id']), ['m9']);
      expect(gap.thread!.count, 60);
      final old = merge(base, ChatPage(items: [msg('m9', '2026-10-25T09:00:00Z')]));
      expect(old.thread!.items.map((m) => m['id']), ['m9']);
      expect(old.thread!.count, isNull);
    });

    test('newestIsMine', () {
      final o = merge(base, ChatPage(items: [msg('m3', '2026-10-25T08:00:02Z', sender: me)], visibleCount: 3));
      expect(o.newestIsMine, isTrue);
    });
  });

  group('upsertLocal', () {
    final base = thread([msg('m1', '2026-10-25T08:00:00Z')]);

    test('+1 only for a new id; the cursor does not move; a duplicate is a no-op', () {
      final sent = msg('m2', '2026-10-25T08:00:10Z', sender: me);
      final s = upsertLocal(base, sent);
      expect(s.count, 2);
      expect(s.cursor, base.cursor);
      expect(s.items.map((m) => m['id']), ['m1', 'm2']);
      expect(identical(upsertLocal(s, sent), s), isTrue);
    });

    test('nothing stored: painted at once, full next time', () {
      final s = upsertLocal(null, msg('m1', '2026-10-25T08:00:00Z', sender: me));
      expect(s.items, hasLength(1));
      expect(s.cursor, isNull);
      expect(s.count, isNull);
      expect(chooseFetch(s, myUid: me, nowMs: now), ChatFetch.full);
    });

    test('local: ids are refused', () {
      expect(identical(upsertLocal(base, msg('local:1', '2026-10-25T08:00:00Z')), base), isTrue);
    });

    test('send, then an incremental read returning it: no duplicate, no full', () {
      final s = upsertLocal(base, msg('m2', '2026-10-25T08:00:10Z', sender: me));
      final o = mergeIncremental(s, ChatPage(items: [msg('m2', '2026-10-25T08:00:10Z', sender: me)], visibleCount: 2),
          myUid: me, nowMs: now, retried: false);
      expect(o.needFull, isFalse);
      expect(o.retryIncremental, isFalse);
      expect(o.added, 0);
      expect(o.thread!.items.map((m) => m['id']), ['m1', 'm2']);
      expect(o.thread!.cursor, '2026-10-25T08:00:10Z');
    });
  });

  test('signature changes only on what a repaint depends on', () {
    final a = [msg('m1', '2026-10-25T08:00:00Z')];
    final sig = signature(a);
    expect(signature([{...a.first, 'body': 'edited text'}]), sig);
    expect(signature([{...a.first, 'attachment_url': 'https://x/1'}]), isNot(sig));
    final signed = signature([{...a.first, 'attachment_url': 'https://x/1'}]);
    expect(signature([{...a.first, 'attachment_url': 'https://x/2'}]), signed);
    expect(signature([{...a.first, 'read_at': '2026-10-25T08:01:00Z'}]), isNot(sig));
    expect(signature([{...a.first, 'moderation_status': 'held'}]), isNot(sig));
    expect(signature([{...a.first, 'moderation': {'appealed': true}}]), isNot(sig));
    expect(signature([{...a.first, 'location': {'updated_at': 'x'}}]), isNot(sig));
    expect(signature([{...a.first, 'location': {'stopped_at': 'x'}}]), isNot(sig));
    expect(signature([...a, msg('m2', '2026-10-25T08:00:01Z')]), isNot(sig));
  });

  test('patchWhere copies before editing', () {
    final s = thread([msg('m1', '2026-10-25T08:00:00Z', extra: {'moderation': {'appealed': false}})]);
    final p = patchWhere(s, (m) => m['id'] == 'm1', (m) => (m['moderation'] as Map)['appealed'] = true);
    expect((p.items.first['moderation'] as Map)['appealed'], isTrue);
    expect((s.items.first['moderation'] as Map)['appealed'], isFalse);
    expect(identical(patchWhere(s, (_) => false, (_) {}), s), isTrue);
  });

  group('CacheRules.patchInbox', () {
    Map<String, dynamic> inbox() => {
          'items': [
            {'id': 'b', 'role': 'buyer', 'unread': 2, 'buyer_unread': 2, 'seller_unread': 0,
             'last_message_at': '2026-10-25T08:00:00Z', 'created_at': '2026-10-01T00:00:00Z'},
            {'id': 'a', 'role': 'seller', 'unread': 1, 'buyer_unread': 0, 'seller_unread': 1,
             'last_message_at': '2026-10-25T08:00:00Z', 'created_at': '2026-10-01T00:00:00Z'},
            {'id': 'c', 'role': 'buyer', 'unread': 0, 'last_message_at': null, 'created_at': '2026-10-02T00:00:00Z'},
          ],
          'total_unread': 3,
        };

    List ids(Map<String, dynamic> body) => (body['items'] as List).map((m) => m['id']).toList();

    test('re-sorts: last_message_at desc, nulls last, then created_at desc, then id asc', () {
      expect(ids(CacheRules.patchInbox(inbox(), 'x')), ['a', 'b', 'c']);
      final moved = CacheRules.patchInbox(inbox(), 'c', lastMessageAt: '2026-10-25 09:00:00.5+00');
      expect(ids(moved), ['c', 'a', 'b']);
      expect((moved['items'] as List).first['last_message_at'], '2026-10-25 09:00:00.5+00');
    });

    test('last_message_at only moves forward', () {
      final p = CacheRules.patchInbox(inbox(), 'b', lastMessageAt: '2026-10-24T00:00:00Z');
      expect((p['items'] as List).firstWhere((m) => m['id'] == 'b')['last_message_at'], '2026-10-25T08:00:00Z');
    });

    test('readByMe clears my side by role and recomputes the total', () {
      final buyer = CacheRules.patchInbox(inbox(), 'b', readByMe: true);
      final b = (buyer['items'] as List).firstWhere((m) => m['id'] == 'b');
      expect([b['unread'], b['buyer_unread']], [0, 0]);
      expect(buyer['total_unread'], 1);
      final seller = CacheRules.patchInbox(inbox(), 'a', readByMe: true);
      final a = (seller['items'] as List).firstWhere((m) => m['id'] == 'a');
      expect([a['unread'], a['seller_unread']], [0, 0]);
      expect(seller['total_unread'], 2);
    });

    test('remove', () {
      final p = CacheRules.patchInbox(inbox(), 'b', remove: true);
      expect(ids(p), ['a', 'c']);
      expect(p['total_unread'], 1);
    });
  });
}

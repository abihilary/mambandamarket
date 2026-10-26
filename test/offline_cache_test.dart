import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/chat_store.dart';
import 'package:mambandamarket/api/chat_sync.dart';
import 'package:mambandamarket/api/offline_cache.dart';

void main() {
  late Directory dir;
  var now = 0;
  int clock() => now;
  const min = 60 * 1000;
  const day = 24 * 60 * min;

  Future<void> put(String key, String body, {String? etag, bool pinned = false}) =>
      OfflineCache.put(key, body, etag: etag, pinned: pinned, startedEpoch: OfflineCache.epoch);

  String k(String uid, String path, [Map<String, String> q = const {}]) => OfflineCache.keyFor(uid, path, q)!;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline_cache_test');
    now = 1800000000000;
    await OfflineCache.initForTest(dir.path, clock: clock);
  });

  tearDown(() async {
    await OfflineCache.closeForTest();
    await dir.delete(recursive: true);
  });

  group('keyFor', () {
    test('uid and path stay in clear; no query, no hash', () {
      expect(OfflineCache.keyFor('u1', '/listings/abc', const {}), 'u1|/listings/abc|');
    });

    test('query order does not change the hash', () {
      final a = OfflineCache.keyFor('u', '/listings', {'a': '1', 'b': '2'})!;
      final b = OfflineCache.keyFor('u', '/listings', {'b': '2', 'a': '1'})!;
      expect(a, b);
      expect(a, matches(RegExp(r'^u\|/listings\|[0-9a-f]{16}$')));
      expect(OfflineCache.keyFor('u', '/listings', {'a': '2', 'b': '1'}), isNot(a));
    });

    test('anon for a null uid', () {
      expect(OfflineCache.keyFor(null, '/categories', const {}), 'anon|/categories|');
    });

    test('a long French search stays within 255 bytes', () {
      final q = 'robe de soirée élégante à manches longues pour mariage traditionnel ' * 6;
      final key = OfflineCache.keyFor('6f1c2d3e-0000-4000-8000-123456789abc', '/listings', {'q': q, 'sort': 'recent'});
      expect(key, isNotNull);
      expect(utf8.encode(key!).length, lessThanOrEqualTo(255));
    });

    test('an oversize key is refused', () {
      expect(OfflineCache.keyFor('u', '/x/${'é' * 200}', const {}), isNull);
    });
  });

  group('put and entry', () {
    test('round-trips body, etag, times and pinned', () async {
      final key = k('u', '/me');
      await put(key, '{"a":1}', etag: 'W/"x"', pinned: true);
      final e = OfflineCache.entry(key)!;
      expect(e.body, '{"a":1}');
      expect(e.etag, 'W/"x"');
      expect(e.savedAt, now);
      expect(e.validatedAt, now);
      expect(e.pinned, isTrue);
      expect(e.age, Duration.zero);
    });

    test('entry sees a put before it is awaited', () async {
      final key = k('u', '/favorites');
      final f = put(key, '{"items":[]}');
      expect(OfflineCache.entry(key)?.body, '{"items":[]}');
      await f;
    });

    test('age is floored at zero when the clock goes back', () async {
      final key = k('u', '/me');
      await put(key, '{}');
      now -= 5 * min;
      expect(OfflineCache.entry(key)!.age, Duration.zero);
    });
  });

  group('touch', () {
    test('memory always moves; disk only every 10 min or on a new etag', () async {
      final key = k('u', '/me');
      final t0 = now;
      await put(key, '{}', etag: 'W/"1"');
      now += min;
      await OfflineCache.touch(key, etag: 'W/"1"', startedEpoch: OfflineCache.epoch);
      expect(OfflineCache.entry(key)!.validatedAt, now);
      expect(OfflineCache.persistedValidatedAt(key), t0);

      now += 11 * min;
      await OfflineCache.touch(key, etag: 'W/"1"', startedEpoch: OfflineCache.epoch);
      expect(OfflineCache.persistedValidatedAt(key), now);

      now += min;
      await OfflineCache.touch(key, etag: 'W/"2"', startedEpoch: OfflineCache.epoch);
      expect(OfflineCache.persistedValidatedAt(key), now);
      expect(OfflineCache.entry(key)!.etag, 'W/"2"');
    });
  });

  group('prune', () {
    test('unpinned go first, oldest first; pinned survive', () async {
      await OfflineCache.initForTest(dir.path, maxEntries: 5, maxChars: 1000, clock: clock);
      await put(k('u', '/me'), '{}', pinned: true);
      for (var i = 0; i < 5; i++) {
        now += min;
        await put(k('u', '/listings/u$i'), '{}');
      }
      expect(OfflineCache.count, 4);
      expect(OfflineCache.keys, containsAll([k('u', '/me'), k('u', '/listings/u2'), k('u', '/listings/u3'), k('u', '/listings/u4')]));
      expect(OfflineCache.keys, isNot(contains(k('u', '/listings/u0'))));
    });

    test('by size, down to 80%', () async {
      await OfflineCache.initForTest(dir.path, maxEntries: 5, maxChars: 1000, clock: clock);
      for (var i = 0; i < 4; i++) {
        now += min;
        await put(k('u', '/listings/s$i'), 'x' * 300);
      }
      expect(OfflineCache.chars, lessThanOrEqualTo(800));
      expect(OfflineCache.keys, [k('u', '/listings/s2'), k('u', '/listings/s3')]);
    });

    test('an oversize body is not saved and does not leave an older copy', () async {
      final key = k('u', '/listings');
      await put(key, '{"old":true}');
      await put(key, 'x' * (OfflineCache.maxEntryChars + 1));
      expect(OfflineCache.entry(key), isNull);
    });

    test('reserved keys are never pruned or counted', () async {
      await OfflineCache.initForTest(dir.path, maxEntries: 5, maxChars: 1000, clock: clock);
      OfflineCache.markGone('dead');
      await OfflineCache.flushGone();
      for (var i = 0; i < 8; i++) {
        now += min;
        await put(k('u', '/listings/r$i'), '{}');
      }
      expect(OfflineCache.count, lessThanOrEqualTo(5));
      expect(OfflineCache.hasReserved('__meta'), isTrue);
      expect(OfflineCache.hasReserved('__gone'), isTrue);
      expect(OfflineCache.keys.where((x) => x.startsWith('__')), isEmpty);
    });
  });

  group('drop', () {
    setUp(() async {
      await put(k('u', '/listings', {'sort': 'recent'}), '{"items":[{"id":"L1"}]}');
      await put(k('u', '/listings', {'category': 'x'}), '{"items":[{"id":"L2"}]}');
      await put(k('u', '/listings/abc'), '{}');
      await put(k('u', '/listings/abc/images'), '{}');
      await put(k('u', '/listings/abcd'), '{}');
      await put(k('v', '/listings/abc'), '{}');
    });

    test("exact '/listings' keeps '/listings/abc'", () async {
      await OfflineCache.drop(exact: ['/listings']);
      expect(OfflineCache.keys, unorderedEquals([
        k('u', '/listings/abc'), k('u', '/listings/abc/images'), k('u', '/listings/abcd'), k('v', '/listings/abc'),
      ]));
    });

    test('a prefix drops itself and below, not its siblings', () async {
      await OfflineCache.drop(uids: {'u'}, prefixes: ['/listings/abc']);
      expect(OfflineCache.entry(k('u', '/listings/abc')), isNull);
      expect(OfflineCache.entry(k('u', '/listings/abc/images')), isNull);
      expect(OfflineCache.entry(k('u', '/listings/abcd')), isNotNull);
    });

    test('bodyContains drops only the bodies that contain it', () async {
      await OfflineCache.drop(exact: ['/listings'], bodyContains: '"id":"L1"');
      expect(OfflineCache.entry(k('u', '/listings', {'sort': 'recent'})), isNull);
      expect(OfflineCache.entry(k('u', '/listings', {'category': 'x'})), isNotNull);
    });

    test('uids limit the drop', () async {
      await OfflineCache.drop(uids: {'u'}, prefixes: ['/listings/abc']);
      expect(OfflineCache.entry(k('v', '/listings/abc')), isNotNull);
    });
  });

  test('stale keeps the body and forgets the etag', () async {
    final key = k('u', '/me');
    await put(key, '{"a":1}', etag: 'W/"1"');
    await OfflineCache.stale(exact: ['/me']);
    expect(OfflineCache.entry(key)!.body, '{"a":1}');
    expect(OfflineCache.entry(key)!.etag, isNull);
  });

  test('patch edits, forgets the etag, keeps the time; null removes', () async {
    final a = k('u', '/conversations');
    final b = k('u', '/favorites');
    await put(a, '{"n":1}', etag: 'W/"1"');
    await put(b, '{"items":[]}', etag: 'W/"1"');
    final t = now;
    now += min;
    await OfflineCache.patch('/conversations', (json) => {...(json as Map).cast<String, dynamic>(), 'n': 2});
    final e = OfflineCache.entry(a)!;
    expect(jsonDecode(e.body), {'n': 2});
    expect(e.etag, isNull);
    expect(e.validatedAt, t);
    await OfflineCache.patch('/favorites', (_) => null);
    expect(OfflineCache.entry(b), isNull);
  });

  group('tombstones', () {
    test('a put that started before a matching drop is ignored; one after is saved', () async {
      final key = k('u', '/favorites');
      final start = OfflineCache.epoch;
      final dropping = OfflineCache.drop(exact: ['/favorites']);
      // Recorded before the drop's future is awaited.
      expect(OfflineCache.supersededSince(key, start), isTrue);
      await dropping;
      await OfflineCache.put(key, '{"old":1}', startedEpoch: start);
      expect(OfflineCache.entry(key), isNull);
      await OfflineCache.put(key, '{"new":1}', startedEpoch: OfflineCache.epoch);
      expect(OfflineCache.entry(key)!.body, '{"new":1}');
      expect(OfflineCache.supersededSince(key, OfflineCache.epoch), isFalse);
    });

    test('a tombstone for another path or account does not supersede', () async {
      final start = OfflineCache.epoch;
      await OfflineCache.drop(uids: {'v'}, exact: ['/favorites']);
      expect(OfflineCache.supersededSince(k('u', '/favorites'), start), isFalse);
      await OfflineCache.drop(uids: {'u'}, exact: ['/me']);
      expect(OfflineCache.supersededSince(k('u', '/favorites'), start), isFalse);
    });
  });

  group('clear and sessions', () {
    test('clear empties everything and an older in-flight put is ignored', () async {
      await put(k('u', '/me'), '{}');
      await put(k('anon', '/categories'), '{}');
      final start = OfflineCache.epoch;
      final gen = OfflineCache.generation;
      final clearing = OfflineCache.clear();
      expect(OfflineCache.entry(k('u', '/me')), isNull);
      await OfflineCache.put(k('u', '/favorites'), '{}', startedEpoch: start);
      await clearing;
      expect(OfflineCache.count, 0);
      expect(OfflineCache.generation, gen + 1);
      expect(OfflineCache.lastUid, isNull);
    });

    test('newSession bumps the generation and supersedes every read', () async {
      final gen = OfflineCache.generation;
      final start = OfflineCache.epoch;
      await OfflineCache.newSession('A');
      expect(OfflineCache.generation, gen + 1);
      expect(OfflineCache.supersededSince(k('A', '/me'), start), isTrue);
    });

    test('adopt(B) after A removes A and keeps anon', () async {
      expect(await OfflineCache.adopt('A'), isNull);
      await put(k('A', '/me'), '{}');
      await put(k('anon', '/categories'), '{}');
      expect(await OfflineCache.adopt('A'), 'A');
      expect(OfflineCache.count, 2);
      expect(await OfflineCache.adopt('B'), 'A');
      expect(OfflineCache.keys, [k('anon', '/categories')]);
      expect(OfflineCache.lastUid, 'B');
    });

    test('on Android, adopt(null) keeps the account (it may sign back in)', () async {
      await OfflineCache.adopt('A');
      await put(k('A', '/me'), '{}');
      await OfflineCache.adopt(null);
      expect(OfflineCache.entry(k('A', '/me')), isNotNull);
      expect(OfflineCache.lastUid, 'A');
    });

    test('on web, adopt(null) removes every non-anon entry', () async {
      await OfflineCache.initForTest(dir.path, clock: clock, web: true);
      await OfflineCache.adopt('A');
      await put(k('A', '/me'), '{}');
      await put(k('anon', '/categories'), '{}');
      await OfflineCache.adopt(null);
      expect(OfflineCache.keys, [k('anon', '/categories')]);
    });

    test('lastUid survives a restart', () async {
      await OfflineCache.adopt('A');
      await OfflineCache.initForTest(dir.path, clock: clock);
      expect(OfflineCache.lastUid, 'A');
    });
  });

  group('gone set', () {
    test('mark, unGone, isGone', () {
      OfflineCache.markGone('x');
      expect(OfflineCache.isGone('x'), isTrue);
      OfflineCache.unGone('x');
      expect(OfflineCache.isGone('x'), isFalse);
    });

    test('expires after 30 days', () {
      OfflineCache.markGone('y');
      now += 31 * day;
      expect(OfflineCache.isGone('y'), isFalse);
    });

    test('keeps the newest 300', () {
      for (var i = 0; i <= 300; i++) {
        OfflineCache.markGone('id$i');
      }
      expect(OfflineCache.isGone('id0'), isFalse);
      expect(OfflineCache.isGone('id1'), isTrue);
      expect(OfflineCache.isGone('id300'), isTrue);
    });

    test('survives a restart', () async {
      OfflineCache.markGone('z');
      await OfflineCache.flushGone();
      await OfflineCache.initForTest(dir.path, clock: clock);
      expect(OfflineCache.isGone('z'), isTrue);
    });
  });

  test('a different API base empties the store', () async {
    await OfflineCache.initForTest(dir.path, clock: clock, base: 'https://a.example');
    await put(k('u', '/me'), '{}');
    await OfflineCache.initForTest(dir.path, clock: clock, base: 'https://a.example');
    expect(OfflineCache.count, 1);
    await OfflineCache.initForTest(dir.path, clock: clock, base: 'https://b.example');
    expect(OfflineCache.count, 0);
  });

  group('ChatStore', () {
    Map<String, dynamic> msg(String id, String at, {String sender = 'me'}) =>
        {'id': id, 'sender_id': sender, 'created_at': at, 'body': id};

    setUp(() async {
      await ChatStore.initForTest(dir.path, clock: clock);
    });

    test('two concurrent updates on one thread both land', () async {
      final gen = OfflineCache.generation;
      final a = ChatStore.update('u', 'c', (cur) => upsertLocal(cur, msg('m1', '2026-10-25T09:00:00Z')), generation: gen);
      final b = ChatStore.update('u', 'c', (cur) => upsertLocal(cur, msg('m2', '2026-10-25T09:00:01Z')), generation: gen);
      await Future.wait([a, b]);
      expect(ChatStore.read('u', 'c')!.items.map((m) => m['id']), ['m1', 'm2']);
    });

    test('an update from an older generation is rejected and writes nothing', () async {
      final stale = OfflineCache.generation;
      await OfflineCache.newSession('B');
      final r = await ChatStore.update('u', 'c', (cur) => upsertLocal(cur, msg('m1', '2026-10-25T09:00:00Z')),
          generation: stale);
      expect(r, isNull);
      expect(ChatStore.read('u', 'c'), isNull);
      expect(ChatStore.persistedRaw('u', 'c'), isNull);
    });

    test('pending (local:) messages are never stored', () async {
      await ChatStore.update('u', 'c', (_) => StoredThread(items: [
            msg('local:1', '2026-10-25T09:00:00Z'),
            msg('m1', '2026-10-25T09:00:01Z'),
          ]), generation: OfflineCache.generation);
      expect(ChatStore.read('u', 'c')!.items.map((m) => m['id']), ['m1']);
      ChatStore.dropMemoryForTest();
      expect(ChatStore.read('u', 'c')!.items.map((m) => m['id']), ['m1']);
    });

    test('past the cap, the least recently opened thread goes', () async {
      for (var i = 0; i <= ChatStore.maxThreads; i++) {
        await ChatStore.update('u', 'c$i', (_) => StoredThread(openedAt: 1000 + i, items: [msg('m$i', '2026-10-25T09:00:00Z')]),
            generation: OfflineCache.generation);
      }
      expect(ChatStore.persistedCount, ChatStore.maxThreads);
      expect(ChatStore.read('u', 'c0'), isNull);
      expect(ChatStore.read('u', 'c1'), isNotNull);
    });

    test('nothing is written when nothing a repaint depends on changed', () async {
      final gen = OfflineCache.generation;
      await ChatStore.update('u', 'c', (_) => StoredThread(cursor: 'x', count: 1, syncedAt: now, items: [msg('m1', '2026-10-25T09:00:00Z')]),
          generation: gen);
      final first = ChatStore.persistedRaw('u', 'c');
      now += min;
      await ChatStore.update('u', 'c', (cur) => cur!.copyWith(syncedAt: now), generation: gen);
      expect(ChatStore.persistedRaw('u', 'c'), first);
      expect(ChatStore.read('u', 'c')!.syncedAt, now);
      now += 11 * min;
      await ChatStore.update('u', 'c', (cur) => cur!.copyWith(syncedAt: now), generation: gen);
      expect(ChatStore.persistedRaw('u', 'c'), isNot(first));
    });

    test('removeOtherUids and retainOnly', () async {
      final gen = OfflineCache.generation;
      for (final key in [('A', 'c1'), ('A', 'c2'), ('B', 'c3')]) {
        await ChatStore.update(key.$1, key.$2, (cur) => upsertLocal(cur, msg('m${key.$2}', '2026-10-25T09:00:00Z')),
            generation: gen);
      }
      await ChatStore.retainOnly('A', {'c1'});
      expect(ChatStore.read('A', 'c2'), isNull);
      expect(ChatStore.read('A', 'c1'), isNotNull);
      expect(ChatStore.read('B', 'c3'), isNotNull);
      await ChatStore.removeOtherUids('A');
      expect(ChatStore.read('B', 'c3'), isNull);
      expect(ChatStore.read('A', 'c1'), isNotNull);
    });
  });
}

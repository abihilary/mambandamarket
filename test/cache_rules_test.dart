import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/api_client.dart';
import 'package:mambandamarket/api/cache_rules.dart';
import 'package:mambandamarket/api/offline_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('every write in lib/ has a rule', () {
    // `.post('/x/$id'`, `.patch(\n  '/x'`, `.delete('/x/${a.b}'`; not the
    // saved-read store's own patch.
    final call = RegExp(r'''(?<!OfflineCache)\.(post|patch|delete)\(\s*(['"])(/[^'"]*)\2''');

    Set<(String, String)> scan() {
      final found = <(String, String)>{};
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.contains('/l10n/gen/')) continue;
        for (final m in call.allMatches(f.readAsStringSync())) {
          final path = m.group(3)!
              .replaceAll(RegExp(r'\$\{[^}]*\}'), 'x1')
              .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), 'x1');
          found.add((m.group(1)!.toUpperCase(), path));
        }
      }
      return found;
    }

    test('the scan finds the writes and each has a rule', () {
      final found = scan();
      expect(found.length, greaterThan(30));
      for (final (method, path) in found) {
        expect(CacheRules.ruleFor(method, path), isNotNull, reason: '$method $path has no CacheRules row');
      }
    });

    test("today's inventory", () {
      const inventory = [
        ('POST', '/account/request-deletion'), ('PATCH', '/me'), ('POST', '/auth/sync'), ('POST', '/referrals/apply'),
        ('POST', '/me/notifications/read'), ('POST', '/me/wallet/withdrawals'),
        ('POST', '/listings'), ('PATCH', '/listings/x1'), ('DELETE', '/listings/x1'),
        ('POST', '/listings/x1/images'), ('PATCH', '/listings/x1/images'), ('DELETE', '/listings/x1/images/x1'),
        ('POST', '/sellers/x1/reviews'), ('POST', '/uploads/sign'), ('POST', '/favorites/x1'), ('DELETE', '/favorites/x1'),
        ('POST', '/stores'), ('PATCH', '/stores/x1'), ('POST', '/stores/x1/reviews'),
        ('POST', '/conversations'), ('POST', '/compliance/appeals'), ('POST', '/conversations/x1/messages'),
        ('POST', '/conversations/x1/location'), ('PATCH', '/conversations/x1/location/x1'),
        ('POST', '/conversations/x1/location/x1/stop'), ('POST', '/conversations/x1/read'),
        ('POST', '/orders'), ('POST', '/orders/x1/pay'), ('POST', '/orders/x1/confirm'), ('POST', '/orders/x1/cancel'),
        ('POST', '/orders/x1/fulfil'),
        ('POST', '/payouts'), ('POST', '/reports'), ('POST', '/support'), ('POST', '/support/thread'),
        ('POST', '/shipping-requests'), ('POST', '/shipping-requests/x1/accept'),
        ('POST', '/devices'), ('DELETE', '/devices/x1'),
      ];
      final found = scan();
      for (final (method, path) in inventory) {
        expect(CacheRules.ruleFor(method, path), isNotNull, reason: '$method $path');
        expect(found, contains((method, path)), reason: 'scan missed $method $path');
      }
      expect(CacheRules.ruleFor('POST', '/something/else'), isNull);
      expect(CacheRules.ruleFor('GET', '/listings'), isNull);
    });
  });

  group('effects', () {
    late Directory dir;
    const me = 'me';
    const other = 'other';
    const anon = 'anon';

    String k(String uid, String path, [Map<String, String> q = const {}]) => OfflineCache.keyFor(uid, path, q)!;
    SavedEntry? e(String uid, String path, [Map<String, String> q = const {}]) => OfflineCache.entry(k(uid, path, q));
    dynamic body(String uid, String path, [Map<String, String> q = const {}]) => jsonDecode(e(uid, path, q)!.body);

    const recent = {'sort': 'recent', 'limit': '40'};
    const other_ = {'category': 'mode', 'sort': 'recent'};

    final seeds = <(String, Map<String, String>, Object)>[
      ('/listings', recent, {'items': [{'id': 'L1', 'status': 'active'}, {'id': 'L2', 'status': 'active'}]}),
      ('/listings', other_, {'items': [{'id': 'L2', 'status': 'active'}]}),
      ('/listings/L1', {}, {'listing': {'id': 'L1', 'is_favorited': false}}),
      ('/listings/L1/related', {'limit': '8'}, {'items': []}),
      ('/listings/L1/images', {}, {'items': []}),
      ('/listings/L2', {}, {'listing': {'id': 'L2'}}),
      ('/favorites', {}, {
        'items': [
          {'listing_id': 'L1', 'listing': {'id': 'L1', 'status': 'active'}},
          {'listing_id': 'L3', 'listing': null},
          {'listing_id': 'L2', 'listing': {'id': 'L2', 'status': 'active'}},
        ],
      }),
      ('/me', {}, {'profile': {'id': me}}),
      ('/sellers/me/dashboard', {}, {'active_listings': 2}),
      ('/sellers/me/listings', {'status': 'all'}, {'items': []}),
      ('/users/me', {}, {'profile': {'id': me}}),
      ('/stores/mine', {}, {'store': null}),
      ('/conversations', {}, {
        'items': [
          {'id': 'C2', 'role': 'buyer', 'unread': 1, 'buyer_unread': 1, 'last_message_at': '2026-10-25T08:00:00Z', 'created_at': '2026-10-01T00:00:00Z'},
          {'id': 'C1', 'role': 'seller', 'unread': 2, 'seller_unread': 2, 'last_message_at': '2026-10-24T08:00:00Z', 'created_at': '2026-10-01T00:00:00Z'},
        ],
        'total_unread': 3,
      }),
      ('/me/notifications', {'limit': '30'}, {
        'items': [
          {'id': 'N1', 'read_at': null},
          {'id': 'N2', 'read_at': null},
          {'id': 'N3', 'read_at': '2026-10-01T00:00:00Z'},
        ],
        'unread': 2,
      }),
      ('/me/notifications/unread', {}, {'unread': 2}),
      ('/me/notifications/home', {}, {'notification': {'id': 'N1'}}),
      ('/me/notifications/N1', {}, {'notification': {'id': 'N1'}}),
      ('/me/notifications/N2', {}, {'notification': {'id': 'N2'}}),
      ('/orders', {}, {'items': []}),
      ('/orders/O1', {}, {'order': {'id': 'O1'}}),
      ('/orders/O2', {}, {'order': {'id': 'O2'}}),
      ('/shipping-requests', {}, {'items': []}),
      ('/shipping-requests/S1', {}, {'request': {'id': 'S1'}}),
      ('/referrals/me', {}, {'code': 'X'}),
    ];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cache_rules_test');
      await OfflineCache.initForTest(dir.path);
      for (final uid in [me, other, anon]) {
        for (final (path, q, b) in seeds) {
          await OfflineCache.put(k(uid, path, q), jsonEncode(b), etag: 'W/"seed"', startedEpoch: OfflineCache.epoch);
        }
      }
    });

    tearDown(() async {
      await OfflineCache.closeForTest();
      await dir.delete(recursive: true);
    });

    Future<void> apply(String method, String path, {Map<String, dynamic>? request, Object? response}) async {
      CacheRules.apply(WriteEvent(method, path, request, response ?? {}, me));
      await pumpEventQueue();
    }

    /// Every seeded entry of [uid] that is still there.
    Set<String> left(String uid) => {
          for (final (path, q, _) in seeds)
            if (e(uid, path, q) != null) q.isEmpty ? path : '$path?${q.values.join(',')}',
        };

    Set<String> all() => {for (final (path, q, _) in seeds) q.isEmpty ? path : '$path?${q.values.join(',')}'};

    void untouched(String uid) => expect(left(uid), all(), reason: '$uid must be untouched');

    test('listing create', () async {
      await apply('POST', '/listings', response: {'listing': {'id': 'L9'}});
      for (final u in [me, anon]) {
        expect(left(u), all().difference({
          '/listings?recent,40', '/listings?mode,recent',
          '/sellers/me/dashboard', '/sellers/me/listings?all', '/users/me', '/stores/mine',
        }), reason: u);
      }
      expect(e(me, '/me')!.etag, isNull);
      expect(e(me, '/me')!.body, isNotEmpty);
      untouched(other);
      expect(e(other, '/me')!.etag, 'W/"seed"');
    });

    test('listing edit', () async {
      await apply('PATCH', '/listings/L1', request: {'title': 'new'});
      expect(left(me), all().difference({
        '/listings?recent,40', '/listings/L1', '/listings/L1/related?8', '/listings/L1/images', '/favorites',
        '/sellers/me/dashboard', '/sellers/me/listings?all', '/users/me',
      }));
      expect(e(me, '/listings', other_), isNotNull);
      expect(e(me, '/me')!.etag, 'W/"seed"');
      expect(OfflineCache.isGone('L1'), isFalse);
      untouched(other);
    });

    const editDrops = {
      '/listings?recent,40', '/listings/L1', '/listings/L1/related?8', '/listings/L1/images', '/favorites',
      '/sellers/me/dashboard', '/sellers/me/listings?all', '/users/me',
    };

    test('listing sold', () async {
      await apply('PATCH', '/listings/L1', request: {'action': 'mark_sold'});
      expect(OfflineCache.isGone('L1'), isTrue);
      expect(left(me), all().difference(editDrops));
      expect(e(me, '/me')!.etag, isNull);
      expect(e(me, '/me')!.body, isNotEmpty);
      expect(e(me, '/conversations')!.etag, 'W/"seed"');
      untouched(other);
    });

    test('listing delete', () async {
      await apply('DELETE', '/listings/L1');
      expect(OfflineCache.isGone('L1'), isTrue);
      for (final u in [me, anon]) {
        expect(left(u), all().difference(editDrops), reason: u);
      }
      expect(e(me, '/me')!.etag, isNull);
      expect(e(me, '/conversations')!.etag, isNull);
      expect(e(me, '/conversations')!.body, isNotEmpty);
      untouched(other);
      expect(e(other, '/conversations')!.etag, 'W/"seed"');
    });

    test('listing images', () async {
      await apply('POST', '/listings/L1/images', request: {'images': []});
      expect(left(me), all().difference({
        '/listings?recent,40', '/listings/L1', '/listings/L1/related?8', '/listings/L1/images',
        '/sellers/me/dashboard', '/sellers/me/listings?all', '/users/me',
      }));
      expect(e(me, '/favorites'), isNotNull);
    });

    test('favourite add', () async {
      await apply('POST', '/favorites/L1');
      expect(body(me, '/listings/L1')['listing']['is_favorited'], isTrue);
      expect(body(anon, '/listings/L1')['listing']['is_favorited'], isTrue);
      expect(body(other, '/listings/L1')['listing']['is_favorited'], isFalse);
      expect(e(me, '/favorites')!.etag, isNull);
    });

    test('favourite remove, including a row whose listing is gone', () async {
      await apply('DELETE', '/favorites/L3');
      expect((body(me, '/favorites')['items'] as List).map((r) => r['listing_id']), ['L1', 'L2']);
      await apply('DELETE', '/favorites/L1');
      expect((body(me, '/favorites')['items'] as List).map((r) => r['listing_id']), ['L2']);
      expect(body(me, '/listings/L1')['listing']['is_favorited'], isFalse);
      expect((body(other, '/favorites')['items'] as List), hasLength(3));
    });

    test('chat send moves the thread up', () async {
      await apply('POST', '/conversations/C1/messages',
          request: {'body': 'hi'}, response: {'message': {'id': 'M1', 'created_at': '2026-10-25 09:00:00.123456+00'}});
      final items = body(me, '/conversations')['items'] as List;
      expect(items.map((t) => t['id']), ['C1', 'C2']);
      expect(items.first['last_message_at'], '2026-10-25 09:00:00.123456+00');
      expect(e(me, '/conversations')!.etag, isNull);
      expect((body(other, '/conversations')['items'] as List).first['id'], 'C2');
    });

    test('chat read clears my unread', () async {
      await apply('POST', '/conversations/C1/read');
      final b = body(me, '/conversations');
      final c1 = (b['items'] as List).firstWhere((t) => t['id'] == 'C1');
      expect([c1['unread'], c1['seller_unread']], [0, 0]);
      expect(b['total_unread'], 1);
    });

    test('notifications read by id', () async {
      await apply('POST', '/me/notifications/read', request: {'ids': ['N1']}, response: {'unread': 1});
      final list = body(me, '/me/notifications', {'limit': '30'});
      final byId = {for (final n in list['items'] as List) n['id']: n['read_at']};
      expect(byId['N1'], isNotNull);
      expect(byId['N2'], isNull);
      expect(list['unread'], 1);
      expect(body(me, '/me/notifications/unread'), {'unread': 1});
      expect(e(me, '/me/notifications/home'), isNull);
      expect(e(me, '/me/notifications/N1'), isNull);
      expect(e(me, '/me/notifications/N2'), isNotNull);
    });

    test('notifications read by id leave a different home card', () async {
      await apply('POST', '/me/notifications/read', request: {'ids': ['N2']}, response: {'unread': 1});
      expect(e(me, '/me/notifications/home'), isNotNull);
      expect(e(me, '/me/notifications/home')!.etag, 'W/"seed"');
    });

    test('notifications all read', () async {
      await apply('POST', '/me/notifications/read', request: {'all': true}, response: {'unread': 0});
      final list = body(me, '/me/notifications', {'limit': '30'});
      expect((list['items'] as List).every((n) => n['read_at'] != null), isTrue);
      expect(list['unread'], 0);
      expect(body(me, '/me/notifications/unread'), {'unread': 0});
      expect(e(me, '/me/notifications/home'), isNull);
    });

    test('profile edit', () async {
      await apply('PATCH', '/me', request: {'notify_marketing': false});
      expect(e(me, '/me')!.etag, isNull);
      expect(e(me, '/me'), isNotNull);
      expect(e(me, '/users/me'), isNull);
      expect(e(me, '/sellers/me/dashboard'), isNotNull);
    });

    test('order pay', () async {
      await apply('POST', '/orders/O1/pay', request: {'provider': 'campay'});
      expect(e(me, '/orders'), isNull);
      expect(e(me, '/orders/O1'), isNull);
      expect(e(me, '/orders/O2'), isNotNull);
      untouched(other);
    });

    test('order create drops the ordered listings', () async {
      await apply('POST', '/orders', request: {
        'items': [
          {'listing_id': 'L2', 'quantity': 1},
        ],
      });
      expect(e(me, '/orders'), isNull);
      expect(e(me, '/listings/L2'), isNull);
      expect(e(me, '/listings/L1'), isNotNull);
    });

    test('shipping create', () async {
      await apply('POST', '/shipping-requests', response: {'request': {'id': 'S2'}});
      expect(e(me, '/shipping-requests'), isNull);
      expect(e(me, '/shipping-requests/S1'), isNotNull);
      expect(e(me, '/conversations')!.etag, isNull);
    });

    test('writes that touch nothing saved', () async {
      for (final (m, p) in [('POST', '/uploads/sign'), ('POST', '/devices'), ('DELETE', '/devices/t'), ('POST', '/reports'),
          ('POST', '/support'), ('POST', '/payouts'), ('POST', '/me/wallet/withdrawals'), ('POST', '/compliance/appeals')]) {
        await apply(m, p);
      }
      untouched(me);
      expect(e(me, '/me')!.etag, 'W/"seed"');
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambandamarket/api/api_client.dart';
import 'package:mambandamarket/api/offline_cache.dart';
import 'package:mambandamarket/api/read_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  var now = 0;
  int clock() => now;
  const day = 24 * 60 * 60 * 1000;

  final seen = <http.Request>[];
  late Future<http.Response> Function(http.Request req) handler;
  String? uid = 'A';

  ApiClient client({Duration timeout = const Duration(seconds: 2), Duration fallback = const Duration(seconds: 1),
          bool web = false}) =>
      ApiClient.test(
        client: MockClient((req) {
          seen.add(req);
          return handler(req);
        }),
        userId: () => uid,
        token: () => uid == null ? null : 'token-$uid',
        timeout: timeout,
        fallbackTimeout: fallback,
        web: web,
      );

  http.Response json(Object body, {int status = 200, String? etag}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json', 'etag': ?etag},
      );

  SavedEntry? saved(String? who, String path, [Map<String, String> q = const {}]) =>
      OfflineCache.entry(OfflineCache.keyFor(who, path, q)!);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('api_client_read_test');
    now = 1800000000000;
    uid = 'A';
    seen.clear();
    await OfflineCache.initForTest(dir.path, clock: clock);
  });

  tearDown(() async {
    await OfflineCache.closeForTest();
    await dir.delete(recursive: true);
  });

  test('1. a 200 with an ETag is saved with it', () async {
    final api = client();
    handler = (_) async => json({'profile': {'id': 'A'}}, etag: 'W/"1"');
    final r = await api.read('/me');
    expect(r.source, ReadSource.network);
    expect(r.isCurrent, isTrue);
    await pumpEventQueue();
    expect(saved('A', '/me')!.etag, 'W/"1"');
  });

  test('2. the next read sends If-None-Match; a 304 answers with the saved body', () async {
    final api = client();
    handler = (_) async => json({'profile': {'id': 'A'}}, etag: 'W/"1"');
    final first = await api.read('/me');
    await pumpEventQueue();
    handler = (req) async => http.Response('', 304, headers: {'etag': 'W/"1"'});
    final second = await api.read('/me');
    expect(seen.last.headers['If-None-Match'], 'W/"1"');
    expect(second.source, ReadSource.notModified);
    expect(second.stamp, first.stamp);
    expect((second.body as Map)['profile'], {'id': 'A'});
  });

  test('3. same body keeps the stamp; a different one changes it and the etag', () async {
    final api = client();
    handler = (_) async => json({'n': 1}, etag: 'W/"1"');
    final a = await api.read('/me');
    final b = await api.read('/me');
    expect(b.stamp, a.stamp);
    handler = (_) async => json({'n': 2}, etag: 'W/"2"');
    final c = await api.read('/me');
    await pumpEventQueue();
    expect(c.stamp, isNot(a.stamp));
    expect(saved('A', '/me')!.etag, 'W/"2"');
  });

  group('4. offline', () {
    test('a network failure answers with the saved copy within the window, and throws beyond', () async {
      final api = client();
      handler = (_) async => json({'n': 1}, etag: 'W/"1"');
      await api.read('/me');
      await pumpEventQueue();
      handler = (_) async => throw const SocketException('no route');
      final r = await api.read('/me');
      expect(r.source, ReadSource.saved);
      expect(r.savedReason, SavedReason.offline);
      expect(r.body, {'n': 1});
      now += 91 * day;
      await expectLater(api.read('/me'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
    });

    test('a read with a saved copy times out on the shorter timeout', () async {
      final api = client(timeout: const Duration(seconds: 2), fallback: const Duration(milliseconds: 50));
      handler = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return json({'n': 1}, etag: 'W/"1"');
      };
      // Nothing saved yet: the long timeout applies and the slow answer lands.
      final first = await api.read('/me');
      expect(first.source, ReadSource.network);
      await pumpEventQueue();
      final sw = Stopwatch()..start();
      final second = await api.read('/me');
      expect(second.source, ReadSource.saved);
      expect(second.savedReason, SavedReason.offline);
      expect(sw.elapsedMilliseconds, lessThan(250));
    });

    test('a timeout beyond the fallback window throws', () async {
      final api = client(timeout: const Duration(milliseconds: 50), fallback: const Duration(milliseconds: 50));
      handler = (_) async => json({'n': 1}, etag: 'W/"1"');
      await api.read('/me');
      await pumpEventQueue();
      handler = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return json({'n': 1});
      };
      now += 91 * day;
      await expectLater(api.read('/me'), throwsA(isA<ApiException>().having((e) => e.isTimeout, 'isTimeout', isTrue)));
    });
  });

  group('5. server unavailable', () {
    for (final status in [502, 503, 504]) {
      test('$status answers with the saved copy', () async {
        final api = client();
        handler = (_) async => json({'n': 1});
        await api.read('/favorites');
        await pumpEventQueue();
        handler = (_) async => http.Response('<html>bad gateway</html>', status);
        final r = await api.read('/favorites');
        expect(r.source, ReadSource.saved);
        expect(r.savedReason, SavedReason.serverUnavailable);
      });
    }

    test('a non-JSON 200 (captive portal) answers with the saved copy', () async {
      final api = client();
      handler = (_) async => json({'n': 1});
      await api.read('/favorites');
      await pumpEventQueue();
      handler = (_) async => http.Response('<html>Sign in to Wi-Fi</html>', 200, headers: {'content-type': 'text/html'});
      final r = await api.read('/favorites');
      expect(r.source, ReadSource.saved);
      expect(r.savedReason, SavedReason.serverUnavailable);
    });

    test('a 500 throws and the saved copy is kept', () async {
      final api = client();
      handler = (_) async => json({'n': 1});
      await api.read('/favorites');
      await pumpEventQueue();
      handler = (_) async => json({'error': {'code': 'boom', 'message': 'x'}}, status: 500);
      await expectLater(api.read('/favorites'), throwsA(isA<ApiException>()));
      expect(saved('A', '/favorites'), isNotNull);
    });
  });

  for (final status in [404, 410]) {
    test('6. a $status drops the saved copy and throws isGone', () async {
      final api = client();
      handler = (_) async => json({'listing': {'id': 'L1'}});
      await api.read('/listings/L1');
      await pumpEventQueue();
      expect(saved('A', '/listings/L1'), isNotNull);
      handler = (_) async => json({'error': {'code': 'not_found', 'message': 'x'}}, status: status);
      await expectLater(api.read('/listings/L1'), throwsA(isA<ApiException>().having((e) => e.isGone, 'isGone', isTrue)));
      await pumpEventQueue();
      expect(saved('A', '/listings/L1'), isNull);
    });
  }

  group('7. policy', () {
    test('searches, later pages, messages, trending, money and quotes are not saved', () async {
      final api = client();
      handler = (_) async => json({'items': []}, etag: 'W/"1"');
      await api.read('/listings', query: {'q': 'robe'});
      await api.read('/listings', query: {'offset': 30});
      await api.read('/conversations/x/messages', query: {'limit': 50});
      await api.read('/trending?category=mode');
      await api.read('/me/wallet');
      await api.read('/shipping/quote?from=${Uri.encodeQueryComponent('Douala, Akwa')}&to=b&size=s');
      await pumpEventQueue();
      expect(OfflineCache.keys, isEmpty);
      // The hand-built query still reaches the server whole.
      expect(seen.last.url.queryParameters, {'from': 'Douala, Akwa', 'to': 'b', 'size': 's'});
    });

    test('/config and /shipping-requests never send If-None-Match', () async {
      final api = client();
      handler = (_) async => json({'items': []}, etag: 'W/"1"');
      for (final path in ['/config', '/shipping-requests']) {
        await api.read(path);
        await pumpEventQueue();
        await api.read(path);
        expect(seen.last.headers.containsKey('If-None-Match'), isFalse, reason: path);
      }
      expect(saved('A', '/shipping-requests'), isNotNull);
      expect(saved('A', '/config'), isNull);
    });

    test('web: /categories is not conditional and orders are not saved', () {
      expect(ReadPolicy.of('/categories', const {}, web: true).conditional, isFalse);
      expect(ReadPolicy.of('/categories', const {}, web: false).conditional, isTrue);
      expect(ReadPolicy.of('/orders/1', const {}, web: true).save, isFalse);
      expect(ReadPolicy.of('/orders', const {}, web: true).save, isFalse);
      expect(ReadPolicy.of('/orders/1', const {}, web: false).actionsOffWhenSaved, isTrue);
    });

    // Vercel's edge answers If-None-Match itself and its 304s drop
    // Access-Control-Allow-Origin: the web build must never send it.
    test('web: no route is conditional, but bodies are still saved and painted', () {
      const paths = [
        '/categories', '/me', '/favorites', '/listings', '/listings/L1', '/listings/L1/related', '/conversations',
        '/conversations/C1', '/me/notifications', '/me/notifications/unread', '/me/notifications/home',
        '/sellers/A/dashboard', '/users/A', '/stores/mine', '/referrals/me', '/boards/home', '/shipping/options',
      ];
      for (final p in paths) {
        final policy = ReadPolicy.of(p, const {}, uid: 'A', web: true);
        expect(policy.conditional, isFalse, reason: p);
        expect(policy.save, isTrue, reason: p);
        expect(ReadPolicy.of(p, const {}, uid: 'A', web: false).conditional, isTrue, reason: p);
      }
      expect(ReadPolicy.of('/me', const {}, web: true).paint, isNotNull);
    });

    test('web: a saved ETag is never sent as If-None-Match', () async {
      final api = client(web: true);
      handler = (_) async => json({'profile': {'id': 'A'}}, etag: 'W/"1"');
      for (final path in ['/me', '/favorites', '/conversations', '/categories']) {
        await api.read(path);
        await pumpEventQueue();
        expect(saved('A', path), isNotNull, reason: path);
        await api.read(path);
        expect(seen.last.headers.keys.map((h) => h.toLowerCase()), isNot(contains('if-none-match')), reason: path);
      }
      expect(api.saved('/me'), isNotNull);
      // The same calls on Android do revalidate.
      final android = client();
      await android.read('/me');
      expect(seen.last.headers['If-None-Match'], 'W/"1"');
    });

    test('an unknown path is not saved', () async {
      final api = client();
      handler = (_) async => json({'ok': true}, etag: 'W/"1"');
      await api.read('/something/new');
      await pumpEventQueue();
      expect(OfflineCache.keys, isEmpty);
      expect(ReadPolicy.of('/something/new', const {}), same(ReadPolicy.none));
    });

    test("a seller's dashboard is pinned only for that seller", () {
      expect(ReadPolicy.of('/sellers/A/dashboard', const {}, uid: 'A').pinned, isTrue);
      expect(ReadPolicy.of('/sellers/A/dashboard', const {}, uid: 'B').pinned, isFalse);
      expect(ReadPolicy.of('/me/notifications', const {'before': 'x'}), same(ReadPolicy.none));
      expect(ReadPolicy.of('/orders', const {'role': 'company'}).save, isFalse);
      expect(ReadPolicy.of('/stores/mine', const {}).pinned, isTrue);
    });
  });

  test("8. one account's copy is invisible to another and to anon", () async {
    final api = client();
    handler = (_) async => json({'profile': {'id': 'A'}});
    await api.read('/me');
    await pumpEventQueue();
    expect(api.saved('/me'), isNotNull);
    handler = (_) async => throw const SocketException('offline');
    for (final who in ['B', null]) {
      uid = who;
      expect(api.saved('/me'), isNull, reason: '$who');
      await expectLater(api.read('/me'), throwsA(isA<ApiException>()), reason: '$who');
    }
  });

  test('9. saved() is null past the paint window and for routes never painted first', () async {
    final api = client();
    handler = (_) async => json({'n': 1});
    await api.read('/me');
    await api.read('/users/x');
    await pumpEventQueue();
    expect(api.saved('/me'), isNotNull);
    expect(saved('A', '/users/x'), isNotNull);
    expect(api.saved('/users/x'), isNull);
    now += 31 * day;
    expect(api.saved('/me'), isNull);
  });

  test('10. a drop while in flight makes the read go again, and only the second answer is saved', () async {
    final api = client();
    final gate = Completer<void>();
    var calls = 0;
    handler = (_) async {
      calls++;
      if (calls == 1) {
        await gate.future;
        return json({'v': 'before the write'});
      }
      return json({'v': 'after the write'});
    };
    final reading = api.read('/favorites');
    await pumpEventQueue();
    await OfflineCache.drop(exact: ['/favorites']);
    gate.complete();
    final r = await reading;
    await pumpEventQueue();
    expect(calls, 2);
    expect(r.body, {'v': 'after the write'});
    expect(jsonDecode(saved('A', '/favorites')!.body), {'v': 'after the write'});
  });

  test('11. an account switch mid-flight: not current, nothing saved', () async {
    final api = client();
    final gate = Completer<void>();
    handler = (_) async {
      await gate.future;
      return json({'profile': {'id': 'A'}});
    };
    final reading = api.read('/me');
    await pumpEventQueue();
    await OfflineCache.newSession('B');
    uid = 'B';
    gate.complete();
    final r = await reading;
    await pumpEventQueue();
    expect(r.isCurrent, isFalse);
    expect(saved('A', '/me'), isNull);
    expect(saved('B', '/me'), isNull);
  });

  test('12. the write hook runs once per successful write, with the uid from before sending', () async {
    final api = client();
    final events = <WriteEvent>[];
    api.onWrite = events.add;
    handler = (_) async {
      uid = 'B'; // the account changes while the request is out
      return json({'ok': true});
    };
    await api.post('/favorites/x');
    expect(events, hasLength(1));
    expect(events.single.method, 'POST');
    expect(events.single.path, '/favorites/x');
    expect(events.single.uid, 'A');

    handler = (_) async => json({'error': {'code': 'boom', 'message': 'x'}}, status: 500);
    await expectLater(api.post('/favorites/y'), throwsA(isA<ApiException>()));
    await expectLater(api.delete('/favorites/y'), throwsA(isA<ApiException>()));
    expect(events, hasLength(1));
  });

  test('ApiException.savedReason', () {
    expect(ApiException(0, 'network', 'x').savedReason, SavedReason.offline);
    expect(ApiException(0, 'timeout', 'x').savedReason, SavedReason.offline);
    expect(ApiException(200, 'bad_response', 'x').savedReason, SavedReason.serverUnavailable);
    expect(ApiException(503, 'http_503', 'x').savedReason, SavedReason.serverUnavailable);
    expect(ApiException(500, 'http_500', 'x').savedReason, isNull);
    expect(ApiException(403, 'forbidden', 'x').savedReason, isNull);
    expect(ApiException(410, 'gone', 'x').isGone, isTrue);
  });
}

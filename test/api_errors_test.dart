import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/api_client.dart';

void main() {
  test('transport failures are told apart', () {
    final net = ApiException(0, 'network', 'x');
    final slow = ApiException(0, 'timeout', 'x');
    expect(net.isNetwork, isTrue);
    expect(net.isTimeout, isFalse);
    expect(slow.isTimeout, isTrue);
    expect(net.reference, 'network');
  });

  test('server and odd replies carry their status', () {
    expect(ApiException(502, 'http_502', 'x').isServer, isTrue);
    expect(ApiException(502, 'http_502', 'x').reference, 'http 502');
    expect(ApiException(200, 'bad_response', 'x').isBadResponse, isTrue);
    expect(ApiException(200, 'bad_response', 'x').reference, 'bad_response · http 200');
    expect(ApiException(404, 'not_found', 'x').isServer, isFalse);
  });
}

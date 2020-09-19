import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../lib/odoo_rpc.dart';
import 'dart:async';

String checksum(String payload) {
  List<int> bytes = utf8.encode(payload);
  return sha256.convert(bytes).toString();
}

http_testing.MockClientHandler fakeRequestHandlerBuilder(final int code) {
  Future<http.Response> fakeRequestHandler(http.Request request) {
    final headers = {
      'Content-type': 'application/json',
      'set-cookie': 'session_id=' + checksum(request.url.path)
    };
    var body = '{"jsonrpc": "2.0", "id": 91215686, "result": []}';
    if (code == 100) {
      body = '{"error": {"code": 100, "message": "Odoo Session Expired"}}';
    }
    if (code == 500) {
      body = '{"error": {"code": 400, "message": "Internal Server Error"}}';
    }
    final response = http.Response(body, code, headers: headers);
    return new Future<http.Response>.sync(() => response);
  }

  return fakeRequestHandler;
}

void main() {
  group('Constructor', () {
    test('Test base URL without trailing slash', () {
      var client = OdooClient('https://demo.erp.co.ua');
      expect(client.baseURL, equals('https://demo.erp.co.ua'));
    });
    test('Test base URL trailing slash', () {
      var client = OdooClient('https://demo.erp.co.ua/web/login');
      expect(client.baseURL, equals('https://demo.erp.co.ua'));
    });
  });
  group('RPC Calls', () {
    test('Test initial session', () {
      var mockHttpClient =
          http_testing.MockClient(fakeRequestHandlerBuilder(200));
      var client = OdooClient(
          'https://demo.erp.co.ua', 'initial session', mockHttpClient);
      expect(client.sessionId, equals('initial session'));
    });
    test('Test refreshing session', () async {
      var mockHttpClient =
          http_testing.MockClient(fakeRequestHandlerBuilder(200));

      var client = OdooClient(
          'https://demo.erp.co.ua', 'initial session', mockHttpClient);

      expect(client.sessionId, equals('initial session'));

      final String expectedSessionId = checksum('/some/path');
      var expectForEvent =
          expectLater(client.sessionStream, emits(expectedSessionId));
      await client.callRPC('/some/path', 'funcName', {});
      expect(client.sessionId, equals(expectedSessionId));
      await expectForEvent;
    });
    test('Test expired session exception', () {
      var mockHttpClient =
          http_testing.MockClient(fakeRequestHandlerBuilder(100));
      var client = OdooClient(
          'https://demo.erp.co.ua', 'initial session', mockHttpClient);
      expect(() async => await client.callRPC('/some/path', 'funcName', {}),
          throwsA(TypeMatcher<OdooSessionExpiredException>()));
    });

    test('Test server error exception', () {
      var mockHttpClient =
          http_testing.MockClient(fakeRequestHandlerBuilder(500));
      var client = OdooClient(
          'https://demo.erp.co.ua', 'initial session', mockHttpClient);
      expect(() async => await client.callRPC('/some/path', 'funcName', {}),
          throwsA(TypeMatcher<OdooException>()));
    });
  });
}

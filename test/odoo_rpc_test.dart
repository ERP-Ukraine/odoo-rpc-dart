import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';

class OdooSessionMatcher extends Matcher {
  String expected;
  late OdooSession actual;
  OdooSessionMatcher(this.expected);

  @override
  Description describe(Description description) {
    return description.add("has expected session = '$expected'");
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map<dynamic, dynamic> matchState, bool verbose) {
    return mismatchDescription
        .add("has actual emitted session = '${matchState['actual'].id}'");
  }

  @override
  bool matches(actual, Map matchState) {
    this.actual = actual as OdooSession;
    matchState['actual'] = actual is String ? actual : null;
    return actual.id == expected;
  }
}

String checksum(String payload) {
  var bytes = utf8.encode(payload);
  return sha256.convert(bytes).toString();
}

http_testing.MockClientHandler getFakeRequestHandler(final int code) {
  Future<http.Response> fakeRequestHandler(http.Request request) {
    // multiple cookies joined with comma
    final headers = {
      'Content-type': 'application/json',
      'set-cookie': '__cfduid=d7aa416b09272df9c8ooooooo84f5d031615155878'
          '; expires=Tue, 06-Apr-21 22:24:38 GMT'
          '; path=/; domain=.mhfly.com; HttpOnly'
          '; SameSite=Lax,session_id=${checksum(request.url.path)}'
          '; Expires=Sat, 05-Jun-2021 22:24:38 GMT; Max-Age=7776000'
          '; HttpOnly; Path=/'
    };
    var body = '{"jsonrpc": "2.0", "id": 91215686, "result": []}';
    if (code == 100) {
      body = '{"error": {"code": 100, "message": "Odoo Session Expired"}}';
    }
    if (code == 500) {
      body = '{"error": {"code": 400, "message": "Internal Server Error"}}';
    }
    final response = http.Response(body, code, headers: headers);
    return Future<http.Response>.sync(() => response);
  }

  return fakeRequestHandler;
}

const OdooSession initialSession = OdooSession(
  id: 'random-session-hash',
  userId: 2,
  partnerId: 3,
  companyId: 1,
  userLogin: 'admin',
  userName: 'Mitchel Admin',
  userLang: 'en_US',
  userTz: 'Europe/Brussels',
  isSystem: true,
  dbName: 'odoo',
  serverVersion: '13',
);

void main() {
  group('Helpers', () {
    test('Test ServerVersionInt', () {
      expect(initialSession.serverVersionInt, equals(13));
      const saasSession = OdooSession(
        id: 'random-session-hash',
        userId: 2,
        partnerId: 3,
        companyId: 1,
        userLogin: 'admin',
        userName: 'Mitchel Admin',
        userLang: 'en_US',
        userTz: 'Europe/Brussels',
        isSystem: true,
        dbName: 'odoo',
        serverVersion: 'saas~15',
      );
      expect(saasSession.serverVersionInt, equals(15));
      const openerpSession = OdooSession(
        id: 'random-session-hash',
        userId: 2,
        partnerId: 3,
        companyId: 1,
        userLogin: 'admin',
        userName: 'Mitchel Admin',
        userLang: 'en_US',
        userTz: 'Europe/Brussels',
        isSystem: true,
        dbName: 'odoo',
        serverVersion: '8',
      );
      expect(openerpSession.serverVersionInt, equals(8));
    });
  });
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
      var mockHttpClient = http_testing.MockClient(getFakeRequestHandler(200));
      var client =
          OdooClient('https://demo.erp.co.ua', initialSession, mockHttpClient);
      expect(client.sessionId!.id, equals(initialSession.id));
    });
    test('Test refreshing session', () async {
      var mockHttpClient = http_testing.MockClient(getFakeRequestHandler(200));

      var client =
          OdooClient('https://demo.erp.co.ua', initialSession, mockHttpClient);

      expect(client.sessionId!.id, equals(initialSession.id));

      final expectedSessionId = checksum('/some/path');
      var expectForEvent = expectLater(
          client.sessionStream, emits(OdooSessionMatcher(expectedSessionId)));
      await client.callRPC('/some/path', 'funcName', {});
      expect(client.sessionId!.id, equals(expectedSessionId));
      await expectForEvent;
    });
    test('Test expired session exception', () {
      var mockHttpClient = http_testing.MockClient(getFakeRequestHandler(100));
      var client =
          OdooClient('https://demo.erp.co.ua', initialSession, mockHttpClient);
      expect(() async => await client.callRPC('/some/path', 'funcName', {}),
          throwsA(TypeMatcher<OdooSessionExpiredException>()));
    });

    test('Test server error exception', () {
      var mockHttpClient = http_testing.MockClient(getFakeRequestHandler(500));
      var client =
          OdooClient('https://demo.erp.co.ua', initialSession, mockHttpClient);
      expect(() async => await client.callRPC('/some/path', 'funcName', {}),
          throwsA(TypeMatcher<OdooException>()));
    });
  });
}

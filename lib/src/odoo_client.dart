import 'dart:convert';
import 'dart:async';
import 'dart:core';
import 'package:uuid/uuid.dart';
import 'package:validators/validators.dart';
import 'package:http/http.dart' as http;

class OdooException implements Exception {
  String message;
  OdooException(this.message);

  @override
  String toString() => 'OdooException: $message';
}

class OdooSessionExpiredException extends OdooException {
  String message;
  OdooSessionExpiredException(this.message) : super(message);

  @override
  String toString() => 'OdooSessionExpiredException: $message';
}

class OdooClient {
  String baseURL;
  String _sessionId;
  bool _sessionStreamActive;
  StreamController<String> _sessionStreamController;
  http.BaseClient httpClient;

  OdooClient(String baseURL,
      [String sessionId = '', http.BaseClient httpClient]) {
    // Restore previous session
    this._sessionId = sessionId;
    // Take or init HTTP client
    this.httpClient = httpClient != null ? httpClient : http.Client();

    // Validate URL
    if (!isURL(baseURL)) {
      throw Exception('Not an URL');
    }
    var baseUri = Uri.parse(baseURL);

    // Take only scheme://host:port
    this.baseURL = baseUri.origin;

    // Disable stream until we get listeners
    this._sessionStreamActive = false;
    this._sessionStreamController = StreamController<String>(
        onListen: _startSteam,
        onPause: _stopStream,
        onResume: _startSteam,
        onCancel: _stopStream);
  }

  void _startSteam() => _sessionStreamActive = true;

  void _stopStream() => _sessionStreamActive = false;

  String get sesionId => this._sessionId;

  Stream<String> get sessionStream => _sessionStreamController.stream;

  // Free HTTP client resources
  void close() {
    if (httpClient != null) {
      httpClient.close();
    }
  }

  // Take new session from cookies
  void _updateSessionId(http.Response response) {
    String rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      int index = rawCookie.indexOf(';');
      var sessionCookie =
          (index == -1) ? rawCookie : rawCookie.substring(0, index);
      if (sessionCookie.split('=').length == 2) {
        _sessionId = sessionCookie.split('=')[1];
        if (_sessionStreamActive) {
          // Send new session to listners
          _sessionStreamController.add(_sessionId);
        }
      }
    }
  }

  // Low Level RPC call.
  // It has to be used on all Odoo Controllers with type='json'
  Future<dynamic> callRPC(path, funcName, params) async {
    var headers = {'Content-type': 'application/json'};

    if (_sessionId != null) {
      headers['Cookie'] = "session_id=" + _sessionId;
    }

    var url = baseURL + path;
    var body = json.encode({
      'jsonrpc': '2.0',
      'method': 'funcName',
      'params': params,
      'id': Uuid().v1()
    });

    final response = await httpClient.post(url, body: body, headers: headers);
    _updateSessionId(response);
    var result = json.decode(response.body);
    if (result['error'] != null) {
      if (result['error']['code'] == 100) {
        // session expired
        _sessionId = '';
        if (_sessionStreamActive) {
          // Send new session to listners
          _sessionStreamController.add(_sessionId);
        }
        final err = result['error'].toString();
        throw OdooSessionExpiredException(err);
      } else {
        // Other error
        final err = result['error'].toString();
        throw OdooException(err);
      }
    }
    return result;
  }

  Future<dynamic> callKw(params) async {
    return callRPC('/web/dataset/call_kw', 'call', params);
  }

  Future<dynamic> authenticate(String db, String login, String password) async {
    var params = {'db': db, 'login': login, 'password': password};
    return callRPC('/web/session/authenticate', 'call', params);
  }

  // raises OdooSessionExpiredException if already destoyed
  Future<dynamic> destroySession() async {
    return callRPC('/web/session/destroy', 'call', {});
  }

  // raises OdooSessionExpiredException if session is not valid
  Future<dynamic> checkSession() async {
    return callRPC('/web/session/check', 'call', {});
  }
}

/// Odoo JSON-RPC Client for authentication and method calls.

import 'dart:convert';
import 'dart:async';
import 'dart:core';

import 'package:uuid/uuid.dart';
import 'package:validators/validators.dart';
import 'package:http/http.dart' as http;

import 'odoo_exceptions.dart';
import 'odoo_session.dart';

/// Odoo client for making RPC calls.
class OdooClient {
  /// Odoo server URL in format proto://domain:port
  String baseURL;

  /// Stores current session_id that is coming from responce cookies.
  /// Odoo server will issue new session for each call as we do cross-origin requests.
  /// Session token can be retrived with SessionId getter.
  OdooSession _sessionId;

  /// Tells whether we should send session change events to a stream.
  /// Activates when there are some listeners.
  bool _sessionStreamActive;

  /// Session change events stream controller
  StreamController<OdooSession> _sessionStreamController;

  /// HTTP client instance. By default instantiated with [http.Client].
  /// Could be overridden for tests or custom client configuration.
  http.BaseClient httpClient;

  /// Instantiates [OdooClient] with given Odoo server URL.
  /// Optionally accepts [sessionId] to reuse existing session.
  /// It is possible to pass own [httpClient] inherited
  /// from [http.BaseClient] to override default one.
  OdooClient(String baseURL,
      [OdooSession sessionId, http.BaseClient httpClient]) {
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
    this._sessionStreamController = StreamController<OdooSession>(
        onListen: _startSteam,
        onPause: _stopStream,
        onResume: _startSteam,
        onCancel: _stopStream);
  }

  void _startSteam() => _sessionStreamActive = true;

  void _stopStream() => _sessionStreamActive = false;

  /// Returns current session
  OdooSession get sessionId => this._sessionId;

  /// Returns stream of session changed events
  Stream<OdooSession> get sessionStream => _sessionStreamController.stream;

  /// Frees HTTP client resources
  void close() {
    if (httpClient != null) {
      httpClient.close();
    }
  }

  void _setSessionId(String newSession) {
    // Update session if exists
    if (_sessionId != null) {
      // session expired
      _sessionId = _sessionId.updateSessionId(newSession);
      if (_sessionStreamActive) {
        // Send new session to listeners
        _sessionStreamController.add(_sessionId);
      }
    }
  }

  // Take new session from cookies and update session instance
  void _updateSessionIdFromCookies(http.Response response) {
    String rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      int index = rawCookie.indexOf(';');
      var sessionCookie =
          (index == -1) ? rawCookie : rawCookie.substring(0, index);
      if (sessionCookie.split('=').length == 2) {
        final newSessionId = sessionCookie.split('=')[1];
        _setSessionId(newSessionId);
      }
    }
  }

  /// Low Level RPC call.
  /// It has to be used on all Odoo Controllers with type='json'
  Future<dynamic> callRPC(path, funcName, params) async {
    var headers = {'Content-type': 'application/json'};

    if (_sessionId != null) {
      headers['Cookie'] = 'session_id=' + _sessionId.id;
    }

    var url = baseURL + path;
    var body = json.encode({
      'jsonrpc': '2.0',
      'method': 'funcName',
      'params': params,
      'id': Uuid().v1()
    });

    final response = await httpClient.post(url, body: body, headers: headers);
    _updateSessionIdFromCookies(response);
    var result = json.decode(response.body);
    if (result['error'] != null) {
      if (result['error']['code'] == 100) {
        // session expired
        _setSessionId('');
        final err = result['error'].toString();
        throw OdooSessionExpiredException(err);
      } else {
        // Other error
        final err = result['error'].toString();
        throw OdooException(err);
      }
    }
    return result['result'];
  }

  /// Calls any public method on a model.
  ///
  /// Throws [OdooException] on any error on Odoo server side.
  /// Throws [OdooSessionExpiredException] when session is expired or not valid.
  Future<dynamic> callKw(params) async {
    return callRPC('/web/dataset/call_kw', 'call', params);
  }

  /// Authenticates user for given database.
  /// This call receives valid session on successful login
  /// which we be reused for future RPC calls.
  Future<OdooSession> authenticate(
      String db, String login, String password) async {
    final params = {'db': db, 'login': login, 'password': password};
    const headers = {'Content-type': 'application/json'};
    final url = baseURL + '/web/session/authenticate';
    final body = json.encode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
      'id': Uuid().v1()
    });

    final response = await httpClient.post(url, body: body, headers: headers);
    var result = json.decode(response.body);
    if (result['error'] != null) {
      if (result['error']['code'] == 100) {
        // session expired
        _setSessionId('');
        final err = result['error'].toString();
        throw OdooSessionExpiredException(err);
      } else {
        // Other error
        final err = result['error'].toString();
        throw OdooException(err);
      }
    }
    _sessionId = OdooSession.fromSessionInfo(result['result']);
    // It will notify subscribers
    _updateSessionIdFromCookies(response);
    return _sessionId;
  }

  /// Destroys current session.
  Future<void> destroySession() async {
    try {
      await callRPC('/web/session/destroy', 'call', {});
      // RPC call sets expired session.
      // Need to overwrite it.
      _setSessionId('');
    } on Exception {
      // If session is not cleared due to
      // unknown error - clear it locally.
      // Remote session will expire on its own.
      _setSessionId('');
    }
  }

  /// Checks if current session is valid.
  /// Throws [OdooSessionExpiredException] if session is not valid.
  Future<dynamic> checkSession() async {
    return callRPC('/web/session/check', 'call', {});
  }
}

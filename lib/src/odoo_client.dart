/// Odoo JSON-RPC Client for authentication and method calls.
import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cookie.dart';
import 'odoo_exceptions.dart';
import 'odoo_session.dart';

enum OdooLoginEvent { loggedIn, loggedOut }

/// Odoo client for making RPC calls.
class OdooClient {
  /// Odoo server URL in format proto://domain:port
  late String baseURL;

  /// Stores current session_id that is coming from responce cookies.
  /// Odoo server will issue new session for each call as we do cross-origin requests.
  /// Session token can be retrived with SessionId getter.
  OdooSession? _sessionId;

  /// Language used by user on website.
  /// It may be different from [OdooSession.userLang]
  String frontendLang = '';

  /// Tells whether we should send session change events to a stream.
  /// Activates when there are some listeners.
  bool _sessionStreamActive = false;

  /// Send LoggedIn and LoggedOut events
  bool _loginStreamActive = false;

  /// Send in request events
  bool _inRequestStreamActive = false;

  /// Session change events stream controller
  late StreamController<OdooSession> _sessionStreamController;

  /// Login events stream controller
  late StreamController<OdooLoginEvent> _loginStreamController;

  /// Sends true while request is executed and false when it's done
  late StreamController<bool> _inRequestStreamController;

  /// HTTP client instance. By default instantiated with [http.Client].
  /// Could be overridden for tests or custom client configuration.
  late http.BaseClient httpClient;

  /// Instantiates [OdooClient] with given Odoo server URL.
  /// Optionally accepts [sessionId] to reuse existing session.
  /// It is possible to pass own [httpClient] inherited
  /// from [http.BaseClient] to override default one.
  OdooClient(String baseURL,
      [OdooSession? sessionId, http.BaseClient? httpClient]) {
    // Restore previous session
    _sessionId = sessionId;
    // Take or init HTTP client
    this.httpClient = httpClient ?? http.Client() as http.BaseClient;

    var baseUri = Uri.parse(baseURL);

    // Take only scheme://host:port
    this.baseURL = baseUri.origin;

    _sessionStreamController = StreamController<OdooSession>.broadcast(
        onListen: _startSessionSteam, onCancel: _stopSessionStream);

    _loginStreamController = StreamController<OdooLoginEvent>.broadcast(
        onListen: _startLoginSteam, onCancel: _stopLoginStream);

    _inRequestStreamController = StreamController<bool>.broadcast(
        onListen: _startInRequestSteam, onCancel: _stopInRequestStream);
  }

  void _startSessionSteam() => _sessionStreamActive = true;

  void _stopSessionStream() => _sessionStreamActive = false;

  void _startLoginSteam() => _loginStreamActive = true;

  void _stopLoginStream() => _loginStreamActive = false;

  void _startInRequestSteam() => _inRequestStreamActive = true;

  void _stopInRequestStream() => _inRequestStreamActive = false;

  /// Returns current session
  OdooSession? get sessionId => _sessionId;

  /// Returns stream of session changed events
  Stream<OdooSession> get sessionStream => _sessionStreamController.stream;

  /// Returns stream of login events
  Stream<OdooLoginEvent> get loginStream => _loginStreamController.stream;

  /// Returns stream of inRequest events
  Stream<bool> get inRequestStream => _inRequestStreamController.stream;
  Future get inRequestStreamDone => _inRequestStreamController.done;

  /// Frees HTTP client resources
  void close() {
    httpClient.close();
  }

  void _setSessionId(String newSessionId, {bool auth = false}) {
    // Update session if exists
    if (_sessionId != null && _sessionId!.id != newSessionId) {
      final currentSessionId = _sessionId!.id;

      if (currentSessionId == '' && !auth) {
        // It is not allowed to init new session outside authenticate().
        // Such may happen when we are already logged out
        // but received late RPC response that contains session in cookies.
        return;
      }

      _sessionId = _sessionId!.updateSessionId(newSessionId);

      if (currentSessionId == '' && _loginStreamActive) {
        // send logged in event
        _loginStreamController.add(OdooLoginEvent.loggedIn);
      }

      if (newSessionId == '' && _loginStreamActive) {
        // send logged out event
        _loginStreamController.add(OdooLoginEvent.loggedOut);
      }

      if (_sessionStreamActive) {
        // Send new session to listeners
        _sessionStreamController.add(_sessionId!);
      }
    }
  }

  // Take new session from cookies and update session instance
  void _updateSessionIdFromCookies(http.Response response,
      {bool auth = false}) {
    // see https://github.com/dart-lang/http/issues/362
    final lookForCommaExpression = RegExp(r'(?<=)(,)(?=[^;]+?=)');
    var cookiesStr = response.headers['set-cookie'];
    if (cookiesStr == null) {
      return;
    }

    for (final cookieStr in cookiesStr.split(lookForCommaExpression)) {
      try {
        final cookie = Cookie.fromSetCookieValue(cookieStr);
        if (cookie.name == 'session_id') {
          _setSessionId(cookie.value, auth: auth);
        }
      } catch (e) {
        throw OdooException(e.toString());
      }
    }
  }

  /// Low Level RPC call.
  /// It has to be used on all Odoo Controllers with type='json'
  Future<dynamic> callRPC(path, funcName, params) async {
    var headers = {'Content-type': 'application/json'};
    var cookie = '';
    if (_sessionId != null) {
      cookie = 'session_id=${_sessionId!.id}';
    }
    if (frontendLang.isNotEmpty) {
      if (cookie.isEmpty) {
        cookie = 'frontend_lang=$frontendLang';
      } else {
        cookie += '; frontend_lang=$frontendLang';
      }
    }
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }

    final uri = Uri.parse(baseURL + path);
    var body = json.encode({
      'jsonrpc': '2.0',
      'method': 'funcName',
      'params': params,
      'id': sha1.convert(utf8.encode(DateTime.now().toString())).toString()
    });

    try {
      if (_inRequestStreamActive) _inRequestStreamController.add(true);
      final response = await httpClient.post(uri, body: body, headers: headers);

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

      if (_inRequestStreamActive) _inRequestStreamController.add(false);
      return result['result'];
    } catch (e) {
      if (_inRequestStreamActive) _inRequestStreamController.add(false);
      rethrow;
    }
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
    final uri = Uri.parse('$baseURL/web/session/authenticate');
    final body = json.encode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
      'id': sha1.convert(utf8.encode(DateTime.now().toString())).toString()
    });
    try {
      if (_inRequestStreamActive) _inRequestStreamController.add(true);
      final response = await httpClient.post(uri, body: body, headers: headers);

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
      // Odoo 11 sets uid to False on failed login without any error message
      if (result['result'].containsKey('uid')) {
        if (result['result']['uid'] is bool) {
          throw OdooException('Authentication failed');
        }
      }

      _sessionId = OdooSession.fromSessionInfo(result['result']);
      // It will notify subscribers
      _updateSessionIdFromCookies(response, auth: true);

      if (_inRequestStreamActive) _inRequestStreamController.add(false);
      return _sessionId!;
    } catch (e) {
      if (_inRequestStreamActive) _inRequestStreamController.add(false);
      rethrow;
    }
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

/// Odoo Session Object

/// Represents session with Odoo server.
class OdooSession {
  /// Current Session id
  final String id;

  /// User's database id
  final int userId;

  /// User's partner database id
  final int partnerId;

  /// User's company database id
  final int companyId;

  /// User's login
  final String userLogin;

  /// User's name
  final String userName;

  /// User's language
  final String userLang;

  /// User's Time zone
  final String userTz;

  /// Is internal user or not
  final bool isSystem;

  /// Database name
  final String dbName;

  /// Server Major version
  final int serverVersion;

  /// [OdooSession] is immutable.
  const OdooSession({
    required this.id,
    required this.userId,
    required this.partnerId,
    required this.companyId,
    required this.userLogin,
    required this.userName,
    required this.userLang,
    required this.userTz,
    required this.isSystem,
    required this.dbName,
    required this.serverVersion,
  });

  /// Creates [OdooSession] instance from odoo session info object.
  static OdooSession fromSessionInfo(Map<String, dynamic> info) {
    final ctx = info['user_context'] as Map<String, dynamic>;
    List<dynamic> versionInfo;
    versionInfo = [9];
    if (info.containsKey('server_version_info')) {
      versionInfo = info['server_version_info'];
    }
    return OdooSession(
      id: info['id'] as String? ?? '',
      userId: info['uid'] as int,
      partnerId: info['partner_id'] as int,
      companyId: info['company_id'] as int,
      userLogin: info['username'] as String,
      userName: info['name'] as String,
      userLang: ctx['lang'] as String,
      userTz: ctx['tz'] is String ? ctx['tz'] as String : 'UTC',
      isSystem: info['is_system'] as bool,
      dbName: info['db'] as String,
      serverVersion: versionInfo[0] as int,
    );
  }

  /// Stores [OdooSession] to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'partnerId': partnerId,
      'companyId': companyId,
      'userLogin': userLogin,
      'userName': userName,
      'userLang': userLang,
      'userTz': userTz,
      'isSystem': isSystem,
      'dbName': dbName,
      'serverVersion': serverVersion,
    };
  }

  /// Restore [OdooSession] from JSON
  static OdooSession fromJson(Map<String, dynamic> json) {
    return OdooSession(
      id: json['id'] as String,
      userId: json['userId'] as int,
      partnerId: json['partnerId'] as int,
      companyId: json['companyId'] as int,
      userLogin: json['userLogin'] as String,
      userName: json['userName'] as String,
      userLang: json['userLang'] as String,
      userTz: json['userTz'] as String,
      isSystem: json['isSystem'] as bool,
      dbName: json['dbName'] as String,
      serverVersion: json['serverVersion'] as int,
    );
  }

  /// Returns new OdooSession instance with updated session id
  OdooSession updateSessionId(String newSessionId) {
    return OdooSession(
      id: newSessionId,
      userId: newSessionId == '' ? 0 : userId,
      partnerId: newSessionId == '' ? 0 : partnerId,
      companyId: newSessionId == '' ? 0 : companyId,
      userLogin: newSessionId == '' ? '' : userLogin,
      userName: newSessionId == '' ? '' : userName,
      userLang: newSessionId == '' ? '' : userLang,
      userTz: newSessionId == '' ? '' : userTz,
      isSystem: newSessionId == '' ? false : isSystem,
      dbName: newSessionId == '' ? '' : dbName,
      serverVersion: newSessionId == '' ? 0 : serverVersion,
    );
  }

  /// String representation of [OdooSession] object.
  @override
  String toString() {
    return 'OdooSession {userName: $userName, userLogin: $userLogin, userId: $userId, companyId: $companyId, id: $id}';
  }
}

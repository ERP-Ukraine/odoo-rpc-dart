/// Odoo Session Object
library;

/// Represents compnay in odooSession.
class Company {
  int id;
  String name;

  Company({required this.id, required this.name});

  /// Stores [Company] to JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  /// Restore [Company] from JSON
  static Company fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  static List<Company> fromJsonList(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((item) => Company.fromJson(item)).toList();
  }

  static List<Map<String, dynamic>> toJsonList(List<Company> companies) {
    return companies.map((item) => item.toJson()).toList();
  }

  @override
  bool operator ==(Object other) {
    if (other is Company) {
      return id == other.id && name == other.name;
    }
    return false;
  }
}

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

  /// User's allowed companies (if supported by beckend)
  final List<Company> allowedCompanies;

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
  final String serverVersion;

  /// [OdooSession] is immutable.
  const OdooSession({
    required this.id,
    required this.userId,
    required this.partnerId,
    required this.companyId,
    required this.allowedCompanies,
    required this.userLogin,
    required this.userName,
    required this.userLang,
    required this.userTz,
    required this.isSystem,
    required this.dbName,
    required this.serverVersion,
  });

  /// Creates [OdooSession] instance from odoo session info object.
  /// See session_info() at web/models/ir_http.py
  static OdooSession fromSessionInfo(Map<String, dynamic> info) {
    final ctx = info['user_context'] as Map<String, dynamic>;
    List<dynamic> versionInfo;
    versionInfo = [9];
    if (info.containsKey('server_version_info')) {
      versionInfo = info['server_version_info'];
    }

    int companyId = 0;
    List<Company> allowedCompanies = [];
    if (info.containsKey('company_id')) {
      companyId = info['company_id'] as int? ?? 0;
    }
    // since Odoo 13.0
    if (info.containsKey('user_companies') &&
        (info['user_companies'] is! bool)) {
      var sessionCurrentCompany = info['user_companies']['current_company'];
      if (sessionCurrentCompany is List) {
        // 12.0, 13.0, 14.0
        companyId = sessionCurrentCompany[0] as int? ?? 0;
      } else {
        // Since 15.0
        companyId = sessionCurrentCompany as int? ?? 0;
      }

      var sessionAllowedCompanies = info['user_companies']['allowed_companies'];
      if (sessionAllowedCompanies is Map) {
        // since 15.0
        for (var e in sessionAllowedCompanies.values) {
          allowedCompanies
              .add(Company(id: e['id'] as int, name: e['name'] as String));
        }
      }
      if (sessionAllowedCompanies is List) {
        // 13.0 and 14.0
        for (var e in sessionAllowedCompanies) {
          allowedCompanies.add(Company(id: e[0], name: e[1]));
        }
      }
    }
    return OdooSession(
      id: info['id'] as String? ?? '',
      userId: info['uid'] as int,
      partnerId: info['partner_id'] as int,
      companyId: companyId,
      allowedCompanies: allowedCompanies,
      userLogin: info['username'] as String,
      userName: info['name'] as String,
      userLang: ctx['lang'] as String,
      userTz: ctx['tz'] is String ? ctx['tz'] as String : 'UTC',
      isSystem: info['is_system'] as bool,
      dbName: info['db'] as String,
      serverVersion: versionInfo[0].toString(),
    );
  }

  /// Stores [OdooSession] to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'partnerId': partnerId,
      'companyId': companyId,
      'allowedCompanies': Company.toJsonList(allowedCompanies),
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
      allowedCompanies: Company.fromJsonList(
          List<Map<String, dynamic>>.from(json['allowedCompanies'])),
      userLogin: json['userLogin'] as String,
      userName: json['userName'] as String,
      userLang: json['userLang'] as String,
      userTz: json['userTz'] as String,
      isSystem: json['isSystem'] as bool,
      dbName: json['dbName'] as String,
      serverVersion: json['serverVersion'].toString(),
    );
  }

  /// Returns new OdooSession instance with updated session id
  OdooSession updateSessionId(String newSessionId) {
    return OdooSession(
      id: newSessionId,
      userId: newSessionId == '' ? 0 : userId,
      partnerId: newSessionId == '' ? 0 : partnerId,
      companyId: newSessionId == '' ? 0 : companyId,
      allowedCompanies: newSessionId == '' ? [] : allowedCompanies,
      userLogin: newSessionId == '' ? '' : userLogin,
      userName: newSessionId == '' ? '' : userName,
      userLang: newSessionId == '' ? '' : userLang,
      userTz: newSessionId == '' ? '' : userTz,
      isSystem: newSessionId == '' ? false : isSystem,
      dbName: newSessionId == '' ? '' : dbName,
      serverVersion: newSessionId == '' ? '' : serverVersion,
    );
  }

  /// [serverVersionInt] returns Odoo server major version as int.
  /// It is useful for for cases like
  /// ```dart
  /// final image_field = session.serverVersionInt >= 13 ? 'image_128' : 'image_small';
  /// ```
  int get serverVersionInt {
    // Take last two chars for name like 'saas~14'
    final serverVersionSanitized = serverVersion.length == 1
        ? serverVersion
        : serverVersion.substring(serverVersion.length - 2);
    return int.tryParse(serverVersionSanitized) ?? -1;
  }

  /// String representation of [OdooSession] object.
  @override
  String toString() {
    return 'OdooSession {userName: $userName, userLogin: $userLogin, userId: $userId, id: $id}';
  }
}

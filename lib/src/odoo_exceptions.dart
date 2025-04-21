/// Odoo exceptions thrown by Odoo client
library;

/// Generic exception thrown on error coming from Odoo server.
class OdooException implements Exception {
  /// Exception message coming from Odoo server.
  Object? error;
  String get message => error.toString();
  OdooException(this.error);

  @override
  String toString() => 'OdooException: $message';
}

/// Exception for session expired error.
class OdooSessionExpiredException extends OdooException {
  OdooSessionExpiredException(super.error);

  @override
  String toString() => 'OdooSessionExpiredException: $message';
}

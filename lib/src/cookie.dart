// Modified version of Cookie class
// from https://github.com/dart-lang/sdk/blob/master/sdk/lib/_http/http_headers.dart
// Thanks to BSD-3 License we can take and modify original code.

// Since http headers parsing code is not yet common for io and http
// and since we want to keep our library compatible with both web and backend usage
// we need to avoid importing Cookie from dart:io and use our own copy of it.

/// Representation of a cookie
class Cookie {
  String _name;
  String _value;
  String? expires;
  int? maxAge;
  String? domain;
  String? _path;
  bool httpOnly = false;
  bool secure = false;

  Cookie(String name, String value)
      : _name = _validateName(name),
        _value = _validateValue(value),
        httpOnly = true;

  String get name => _name;
  String get value => _value;

  String? get path => _path;

  set path(String? newPath) {
    _validatePath(newPath);
    _path = newPath;
  }

  set name(String newName) {
    _validateName(newName);
    _name = newName;
  }

  set value(String newValue) {
    _validateValue(newValue);
    _value = newValue;
  }

  Cookie.fromSetCookieValue(String value)
      : _name = '',
        _value = '' {
    // Parse the 'set-cookie' header value.
    _parseSetCookieValue(value);
  }

  // Parse a 'set-cookie' header value according to the rules in RFC 6265.
  void _parseSetCookieValue(String s) {
    var index = 0;

    bool done() => index == s.length;

    String parseName() {
      var start = index;
      while (!done()) {
        if (s[index] == '=') break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    String parseValue() {
      var start = index;
      while (!done()) {
        if (s[index] == ';') break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    void parseAttributes() {
      String parseAttributeName() {
        var start = index;
        while (!done()) {
          if (s[index] == '=' || s[index] == ';') break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      String parseAttributeValue() {
        var start = index;
        while (!done()) {
          if (s[index] == ';') break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      while (!done()) {
        var name = parseAttributeName();
        var value = '';
        if (!done() && s[index] == '=') {
          index++; // Skip the = character.
          value = parseAttributeValue();
        }
        if (name == 'expires') {
          expires = value;
        } else if (name == 'max-age') {
          maxAge = int.parse(value);
        } else if (name == 'domain') {
          domain = value;
        } else if (name == 'path') {
          path = value;
        } else if (name == 'httponly') {
          httpOnly = true;
        } else if (name == 'secure') {
          secure = true;
        }
        if (!done()) index++; // Skip the ; character
      }
    }

    _name = _validateName(parseName());
    if (done() || _name.isEmpty) {
      throw Exception('Failed to parse header value [$s]');
    }
    index++; // Skip the = character.
    _value = _validateValue(parseValue());
    if (done()) return;
    index++; // Skip the ; character.
    parseAttributes();
  }

  @override
  String toString() {
    var sb = StringBuffer();
    sb
      ..write(_name)
      ..write('=')
      ..write(_value);
    var expires = this.expires;
    if (expires != null) {
      sb
        ..write('; Expires=')
        ..write(expires);
    }
    if (maxAge != null) {
      sb
        ..write('; Max-Age=')
        ..write(maxAge);
    }
    if (domain != null) {
      sb
        ..write('; Domain=')
        ..write(domain);
    }
    if (path != null) {
      sb
        ..write('; Path=')
        ..write(path);
    }
    if (secure) sb.write('; Secure');
    if (httpOnly) sb.write('; HttpOnly');
    return sb.toString();
  }

  static String _validateName(String newName) {
    const separators = [
      '(',
      ')',
      '<',
      '>',
      '@',
      ',',
      ';',
      ':',
      '\\',
      '"',
      '/',
      '[',
      ']',
      '?',
      '=',
      '{',
      '}'
    ];
    for (var i = 0; i < newName.length; i++) {
      var codeUnit = newName.codeUnitAt(i);
      if (codeUnit <= 32 ||
          codeUnit >= 127 ||
          separators.contains(newName[i])) {
        throw FormatException(
            "Invalid character in cookie name, code unit: '$codeUnit'",
            newName,
            i);
      }
    }
    return newName;
  }

  static String _validateValue(String newValue) {
    // Per RFC 6265, consider surrounding "" as part of the value, but otherwise
    // double quotes are not allowed.
    var start = 0;
    var end = newValue.length;
    if (2 <= newValue.length &&
        newValue.codeUnits[start] == 0x22 &&
        newValue.codeUnits[end - 1] == 0x22) {
      start++;
      end--;
    }

    for (var i = start; i < end; i++) {
      var codeUnit = newValue.codeUnits[i];
      if (!(codeUnit == 0x21 ||
          (codeUnit >= 0x23 && codeUnit <= 0x2B) ||
          (codeUnit >= 0x2D && codeUnit <= 0x3A) ||
          (codeUnit >= 0x3C && codeUnit <= 0x5B) ||
          (codeUnit >= 0x5D && codeUnit <= 0x7E))) {
        throw FormatException(
            "Invalid character in cookie value, code unit: '$codeUnit'",
            newValue,
            i);
      }
    }
    return newValue;
  }

  static void _validatePath(String? path) {
    if (path == null) return;
    for (var i = 0; i < path.length; i++) {
      var codeUnit = path.codeUnitAt(i);
      // According to RFC 6265, semicolon and controls should not occur in the
      // path.
      // path-value = <any CHAR except CTLs or ";">
      // CTLs = %x00-1F / %x7F
      if (codeUnit < 0x20 || codeUnit >= 0x7f || codeUnit == 0x3b /*;*/) {
        throw FormatException(
            "Invalid character in cookie path, code unit: '$codeUnit'");
      }
    }
  }
}

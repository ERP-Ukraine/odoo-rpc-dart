# Odoo RPC Client Library

Odoo RPC Client Library for Dart.

## Features

- initialize client with previously stored `session_id`
- authenticate via database name, login and password
- issue JSON-RPC requests to JSON controllers
- execute methods via call_kw
- get `session_id` updates via stream
- terminate session (logout)
- catch exceptions when session expires

## Usage

To use this plugin, add odoo_rpc as a dependency in your pubspec.yaml file. For example:

```yaml
dependencies:
  odoo_rpc: ^0.1.7
```

## Examples

Basic RPC-call

```dart
import 'dart:io';
import 'packages:odoo_rpc/odoo_rpc.dart'

main() async {
  var client = OdooClient("https://my-db.odoo.com");
  try {
    var res = await client.authenticate('my-db', 'admin', 'admin');
    res = await client.callRPC('/web/session/modules', 'call', {});
    print('Installed modules: \n' + res.toString());
  } on OdooException catch (e) {
    print(e);
    client.close();
    exit(-1);
  }
  client.close();
}
```

RPC-Calls with tracking session changes. Odoo server will issue new `session_id` on each call.

```dart
import 'dart:io';
import 'packages:odoo_rpc/odoo_rpc.dart'


sessionChanged(String sessionId) async {
  print('We got new session ID: ' + sessionId);
  store_session_somehow(sessionId)
}


main() async {
  var prev_session = restore_session_somehow();
  var client = OdooClient("https://my-db.odoo.com", prev_session);

  // Subscribe to session changes to store most recent one
  var subscription = client.sessionStream.listen(sessionChanged);

  try {
    var res = await client.authenticate('my-db', 'admin', 'admin');
    res = await client.callRPC('/web/session/modules', 'call', {});
    print('Installed modules: \n' + res.toString());

    // logout
    await client.destroySession();
  } on OdooException catch (e) {
    print(e);
    subscription.cancel();
    client.close();
    exit(-1);
  }

  try {
    await client.checkSession();
  } on OdooSessionExpiredException {
    print('Session expired');
  }

  subscription.cancel();
  client.close();
}
```

See example folder for more complete example.

## Issues

Please file any issues, bugs or feature requests as an issue on our [GitHub](https://github.com/ERP-Ukraine/odoo-rpc-dart/issues) page.

## Want to contribute

If you would like to contribute to the plugin (e.g. by improving the documentation, solving a bug or adding a cool new feature), please send us your [pull request](https://github.com/ERP-Ukraine/odoo-rpc-dart/pulls).

## Author

This Geolocator plugin for Flutter is developed by [ERP Ukraine](https://erp.co.ua).

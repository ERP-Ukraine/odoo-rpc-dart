# Odoo RPC Client Library

Odoo RPC Client Library for Dart.

## Features

- Initialize client with previously stored Odoo Session.
- Authenticate via database name, login and password.
- Issue JSON-RPC requests to JSON controllers.
- Execute public methods via `CallKw`.
- Get Odoo Session updates via stream.
- Terminate session (logout).
- Catch exceptions when session expires.

## Usage

To use this plugin, add odoo_rpc as a dependency in your pubspec.yaml file. For example:

```yaml
dependencies:
  odoo_rpc: ^0.4.5
```

## Examples

Basic RPC-call

```dart
import 'dart:io';
import 'package:odoo_rpc/odoo_rpc.dart'

main() async {
  final client = OdooClient('https://my-db.odoo.com');
  try {
    await client.authenticate('my-db', 'admin', 'admin');
    final res = await client.callRPC('/web/session/modules', 'call', {});
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
import 'package:odoo_rpc/odoo_rpc.dart'


sessionChanged(OdooSession sessionId) async {
  print('We got new session ID: ' + sessionId.id);
  store_session_somehow(sessionId);
}


main() async {
  var prev_session = restore_session_somehow();
  var client = OdooClient("https://my-db.odoo.com", prev_session);

  // Subscribe to session changes to store most recent one
  var subscription = client.sessionStream.listen(sessionChanged);

  try {
    final session = await client.authenticate('my-db', 'admin', 'admin');
    var res = await client.callRPC('/web/session/modules', 'call', {});
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

Flutter [example](https://github.com/ERP-Ukraine/odoo-rpc-flutter-demo) using `FutureBuilder`.

```dart
import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

final orpc = OdooClient('https://my-odoo-instance.com');
void main() async {
  await orpc.authenticate('odoo-db', 'admin', 'admin');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  Future<dynamic> fetchContacts() {
    return orpc.callKw({
      'model': 'res.partner',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [],
        'fields': ['id', 'name', 'email', '__last_update', 'image_128'],
        'limit': 80,
      },
    });
  }

  Widget buildListItem(Map<String, dynamic> record) {
    var unique = record['__last_update'] as String;
    unique = unique.replaceAll(RegExp(r'[^0-9]'), '');
    final avatarUrl =
        '${orpc.baseURL}/web/image?model=res.partner&field=image_128&id=${record["id"]}&unique=$unique';
    return ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
      title: Text(record['name']),
      subtitle: Text(record['email'] is String ? record['email'] : ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts'),
      ),
      body: Center(
        child: FutureBuilder(
            future: fetchContacts(),
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (context, index) {
                      final record =
                          snapshot.data[index] as Map<String, dynamic>;
                      return buildListItem(record);
                    });
              } else {
                if (snapshot.hasError) return Text('Unable to fetch data');
                return CircularProgressIndicator();
              }
            }),
      ),
    );
  }
}
```

For more complex usage consider [odoo_repository](https://pub.dev/packages/odoo_repository) as abstraction layer between your flutter app and Odoo backend.

## Web platform notice

This package intentionally uses `http` package instead of `dart:io` so web platform could be supported.
However RPC calls via web client (dart js) that is hosted on separate domain will not work
due to CORS requests currently are not correctly handled by Odoo.
See [https://github.com/odoo/odoo/pull/37853](https://github.com/odoo/odoo/pull/37853) for the details.

## Issues

Please file any issues, bugs or feature requests as an issue on our [GitHub](https://github.com/ERP-Ukraine/odoo-rpc-dart/issues) page.

## Want to contribute

If you would like to contribute to the plugin (e.g. by improving the documentation, solving a bug or adding a cool new feature), please send us your [pull request](https://github.com/ERP-Ukraine/odoo-rpc-dart/pulls).

## Author

Odoo RPC Client Library is developed by [ERP Ukraine](https://erp.co.ua).

import 'dart:io';

import '../lib/odoo_rpc.dart';

sessionChanged(OdooSession sessionId) async {
  print('We got new session ID: ' + sessionId.id);
  // write to persistent storage
}

main() async {
  // Restore session ID from storage and pass it to client constructor.
  final baseUrl = 'https://demo.odoo.com';
  final client = OdooClient(baseUrl);
  // Subscribe to session changes to store most recent one
  var subscription = client.sessionStream.listen(sessionChanged);

  try {
    final session = await client.authenticate('odoo', 'admin', 'admin');
    print(session);
    print('Authenticated');
    final image_field =
        session.serverVersion >= 13 ? 'image_128' : 'image_small';
    var res = await client.callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['id', '=', session.userId]
        ],
        'fields': ['id', 'name', '__last_update', image_field],
      },
    });
    print('\nUser info: \n' + res.toString()) as List<dynamic>;
    final uid = session.userId;
    if (res.length == 1) {
      var unique = res[0]['__last_update'] as String;
      unique = unique.replaceAll(new RegExp(r'[^0-9]'), '');
      final user_avatar =
          '$baseUrl/web/image?model=res.user&field=$image_field&id=$uid&unique=$unique';
      print('User Avatar URL: $user_avatar');
    }
    res = await client.callRPC('/web/session/modules', 'call', {});
    print('\nInstalled modules: \n' + res.toString());

    print('\nChecking session while logged in');
    res = await client.checkSession();
    print(res);

    print('\nDestroying session');
    await client.destroySession();
    print(res);
  } on OdooException catch (e) {
    print(e);
    subscription.cancel();
    client.close();
    exit(-1);
  }

  print('\nChecking session while logged out');
  try {
    var res = await client.checkSession();
    print(res);
  } on OdooSessionExpiredException {
    print('Session expired');
  }

  subscription.cancel();
  client.close();
}

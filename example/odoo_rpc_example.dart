import 'dart:io';

import '../lib/odoo_rpc.dart';

sessionChanged(OdooSession sessionId) async {
  print('We got new session ID: ' + sessionId.id);
  // write to persistent storage
}

main() async {
  // Restore session ID from storage and pass it to client constructor.
  final client = OdooClient("https://demo.odoo.com");
  // Subscribe to session changes to store most recent one
  var subscription = client.sessionStream.listen(sessionChanged);

  try {
    final session = await client.authenticate('odoo', 'admin', 'admin');
    print(session);
    print('Authenticated');

    var res = await client.callRPC('/web/session/modules', 'call', {});
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

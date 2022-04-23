import 'dart:io';

import '../lib/odoo_rpc.dart';

void sessionChanged(OdooSession sessionId) async {
  print('We got new session ID: ' + sessionId.id);
  // write to persistent storage
}

void loginStateChanged(OdooLoginEvent event) async {
  if (event == OdooLoginEvent.loggedIn) {
    print('Logged in');
  }
  if (event == OdooLoginEvent.loggedOut) {
    print('Logged out');
  }
}

void inRequestChanged(bool event) async {
  if (event) print('Request is executing'); // draw progress indicator
  if (!event) print('Request is finished'); // hide progress indicator
}

void main() async {
  // Restore session ID from storage and pass it to client constructor.
  final baseUrl = 'https://demo.odoo.com';
  final client = OdooClient(baseUrl);
  // Subscribe to session changes to store most recent one
  var subscription = client.sessionStream.listen(sessionChanged);
  var loginSubscription = client.loginStream.listen(loginStateChanged);
  var inRequestSubscription = client.inRequestStream.listen(inRequestChanged);

  try {
    // Authenticate to server with db name and credentials
    final session = await client.authenticate('odoo', 'admin', 'admin');
    print(session);
    print('Authenticated');

    // Compute image avatar field name depending on server version
    final image_field =
        session.serverVersionInt >= 13 ? 'image_128' : 'image_small';

    // Read our user's fields
    final uid = session.userId;
    var res = await client.callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['id', '=', uid]
        ],
        'fields': ['id', 'name', '__last_update', image_field],
      },
    });
    print('\nUser info: \n' + res.toString());
    // compute avatar url if we got reply
    if (res.length == 1) {
      var unique = res[0]['__last_update'] as String;
      unique = unique.replaceAll(RegExp(r'[^0-9]'), '');
      final user_avatar =
          '$baseUrl/web/image?model=res.user&field=$image_field&id=$uid&unique=$unique';
      print('User Avatar URL: $user_avatar');
    }

    // Create partner
    var partner_id = await client.callKw({
      'model': 'res.partner',
      'method': 'create',
      'args': [
        {
          'name': 'Stealthy Wood',
        },
      ],
      'kwargs': {},
    });
    // Update partner by id
    res = await client.callKw({
      'model': 'res.partner',
      'method': 'write',
      'args': [
        partner_id,
        {
          'is_company': true,
        },
      ],
      'kwargs': {},
    });

    // Get list of installed modules
    res = await client.callRPC('/web/session/modules', 'call', {});
    print('\nInstalled modules: \n' + res.toString());

    // Check if loggeed in
    print('\nChecking session while logged in');
    res = await client.checkSession();
    print('ok');

    // Log out
    print('\nDestroying session');
    await client.destroySession();
    print('ok');
  } on OdooException catch (e) {
    // Cleanup on odoo exception
    print(e);
    await subscription.cancel();
    await loginSubscription.cancel();
    await inRequestSubscription.cancel();
    client.close();
    exit(-1);
  }

  print('\nChecking session while logged out');
  try {
    var res = await client.checkSession();
    print(res);
  } on OdooSessionExpiredException {
    print('Odoo Exception:Session expired');
  }
  await client.inRequestStream.isEmpty;
  await subscription.cancel();
  await loginSubscription.cancel();
  await inRequestSubscription.cancel();
  client.close();
}

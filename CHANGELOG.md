# odoo_prc changelog

## 0.2.6

Session info may not have server info key.

## 0.2.5

Handle unsuccessful login for older Odoo versions.

## 0.2.4

Clear sessionId after logout.
Final RPC call receives expired session in cookies.

## 0.2.3

Lower meta version dependency to make flutter_test happy.

## 0.2.2

Added login and db name to session object.

## 0.2.1

Updated the example with search_read call.

## 0.2.0

Introduced OdooSession object.

## 0.1.7

Now session is destroyed even on network error.

## 0.1.6

Fixed more typos.

## 0.1.5

Fixed sessionId getter typo.

## 0.1.4

Format code with dartfmt.

## 0.1.3

Added dartdoc comments for public methods.

## 0.1.2

Fixed indents in Readme file

## 0.1.1

Updated package layout according to guidelines

## 0.1.0

Initial Version of the library.

- Includes the ability to issue RPC calls to Odoo server while handling session_id changes on every request.

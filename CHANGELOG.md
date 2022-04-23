# odoo_rpc changelog

## 0.5.1

Add serverVersionInt helper

## 0.5.0

Treat serverVersion as String

## 0.4.5

Removed dependency on pre-release sdk

## 0.4.4

Removed dependency on pre-release sdk

## 0.4.3

Handle multiple cookies joined with comma

## 0.4.2

Fixed type castins for session info

## 0.4.1

Pedantic refactor

## 0.4.0

Release null-safety version

## 0.4.0-nullsafety.6

Add in reqest stream. It will allow to show progress bar while request is executed.

## 0.4.0-nullsafety.5

Add optional frontendLang to mimic user's website language.
Now it is possible to track phone's locale changes and
issue requests with updated language as if it it was set on website.

## 0.4.0-nullsafety.4

Removed dependency on uuid package.
It allowed to change all dependencies to nullsafety version.

## 0.4.0-nullsafety.3

Init session id with empty string if not provided

## 0.4.0-nullsafety.2

Add LoggedIn/LoggedOut events

## 0.4.0-nullsafety.1

Drop dependency on validators package.

## 0.4.0-nullsafety0

Pre-release of null safety

## 0.3.1

Migrate to null safety

## 0.3.0

Use broadcast stream for session update events

## 0.2.9

Fix typos in README

## 0.2.8

Handle a case when user's timezone is false instead of String.

## 0.2.7

Add example of how to create partner.

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

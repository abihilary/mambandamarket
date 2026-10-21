import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Open [uri] outside the app: the browser, the payment page, the PDF viewer.
///
/// On the web a new tab opened after an `await` — after asking the server for
/// the payment page or the document — is stopped by Safari's pop-up blocker,
/// and `launchUrl` still answers true, so nothing on screen says it failed.
/// [afterAwait] puts it in the same tab there instead; the browser's back
/// button returns to the app. On a phone it is the external app, as before.
Future<bool> openExternal(Uri uri, {bool afterAwait = false}) {
  if (kIsWeb) {
    return launchUrl(uri, webOnlyWindowName: afterAwait ? '_self' : '_blank');
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

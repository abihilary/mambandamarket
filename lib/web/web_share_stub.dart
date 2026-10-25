/// How a web share ended.
enum WebShareOutcome { shared, dismissed, unsupported }

/// Only the web build has a browser to ask.
Future<WebShareOutcome> webShare({
  required String title,
  String? text,
  String? url,
}) async =>
    WebShareOutcome.unsupported;

/// Only the web build has a share sheet to ask about.
bool webCanShare() => false;

/// Only the web build copies through the browser.
Future<bool> webCopy(String text) async => false;

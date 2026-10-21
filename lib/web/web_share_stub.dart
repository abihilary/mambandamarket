/// How a web share ended.
enum WebShareOutcome { shared, dismissed, unsupported }

/// Only the web build has a browser to ask.
Future<WebShareOutcome> webShare({
  required String title,
  required String text,
}) async =>
    WebShareOutcome.unsupported;

/// Only the web build copies through the browser.
Future<bool> webCopy(String text) async => false;

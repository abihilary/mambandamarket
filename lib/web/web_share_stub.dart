/// How a web share ended.
enum WebShareOutcome { shared, dismissed, unsupported }

/// Only the web build has a browser to ask.
Future<WebShareOutcome> webShare({
  required String title,
  required String text,
}) async =>
    WebShareOutcome.unsupported;

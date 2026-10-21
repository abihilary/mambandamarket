import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// How a web share ended.
enum WebShareOutcome { shared, dismissed, unsupported }

/// `navigator.share`, called directly.
///
/// Not share_plus on the web: where the browser has no share sheet (most
/// desktop browsers) it opens a `mailto:` link instead — an email app, or
/// nothing at all — and where the sheet does work it still reports
/// "unavailable", so the app followed every successful share with "Sharing is
/// not available on this device". Here a missing sheet is reported as such,
/// and the caller copies the link instead.
///
/// Call it straight from the tap, before any await: browsers only allow a
/// share from inside the user's gesture.
Future<WebShareOutcome> webShare({
  required String title,
  required String text,
}) async {
  final navigator = globalContext['navigator'] as JSObject?;
  if (navigator == null || !navigator.has('share')) {
    return WebShareOutcome.unsupported;
  }
  final data = {'title': title, 'text': text}.jsify()!;
  try {
    await navigator.callMethod<JSPromise<JSAny?>>('share'.toJS, data).toDart;
    return WebShareOutcome.shared;
  } catch (e) {
    // AbortError is the person closing the sheet. Anything else (a
    // NotAllowedError when the gesture was lost) means the sheet never came
    // up, so the link is copied instead.
    return e.toString().contains('AbortError')
        ? WebShareOutcome.dismissed
        : WebShareOutcome.unsupported;
  }
}

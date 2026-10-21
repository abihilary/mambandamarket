import 'dart:async';
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

/// Put [text] on the clipboard, reporting honestly whether it got there.
///
/// Flutter's Clipboard.setData on the web did not report a refusal: when the
/// browser said no ("Write permission denied", which Safari and an unfocused
/// page both do) the tap simply did nothing. This asks the async clipboard
/// first, then the older execCommand('copy') — which some browsers still allow
/// when the first is refused — and returns false only when both fail, so the
/// caller can show the link to copy by hand.
Future<bool> webCopy(String text) async {
  final navigator = globalContext['navigator'] as JSObject?;
  final clipboard = navigator?['clipboard'] as JSObject?;
  if (clipboard != null && clipboard.has('writeText')) {
    try {
      await clipboard
          .callMethod<JSPromise<JSAny?>>('writeText'.toJS, text.toJS)
          .toDart
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (_) {
      // Refused or hung; try the old way below.
    }
  }
  try {
    final document = globalContext['document']! as JSObject;
    final body = document['body']! as JSObject;
    // Selecting the textarea takes focus out of the app; it goes back after,
    // or the app treats the tap as having left it.
    final previous = document['activeElement'] as JSObject?;
    final area =
        document.callMethod<JSObject>('createElement'.toJS, 'textarea'.toJS);
    area['value'] = text.toJS;
    final style = area['style']! as JSObject;
    style['position'] = 'fixed'.toJS;
    style['opacity'] = '0'.toJS;
    body.callMethod<JSAny?>('appendChild'.toJS, area);
    area.callMethod<JSAny?>('select'.toJS);
    final ok = document
            .callMethod<JSBoolean?>('execCommand'.toJS, 'copy'.toJS)
            ?.toDart ??
        false;
    body.callMethod<JSAny?>('removeChild'.toJS, area);
    previous?.callMethod<JSAny?>('focus'.toJS);
    return ok;
  } catch (_) {
    return false;
  }
}

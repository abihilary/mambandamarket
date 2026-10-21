import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Show the iOS install card, if the page decides it applies: Safari on an
/// iPhone, not already installed, not dismissed before. Once per page load.
void offerInstall() {
  try {
    if (globalContext.has('mambandaOfferInstall')) {
      globalContext.callMethod('mambandaOfferInstall'.toJS);
    }
  } catch (_) {
    // The card is a nicety; nothing depends on it.
  }
}

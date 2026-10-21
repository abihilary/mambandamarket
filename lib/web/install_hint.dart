// Asks the page to show the iOS "Add to Home Screen" card (web/index.html).
// A no-op everywhere but the web build.
export 'install_hint_stub.dart'
    if (dart.library.js_interop) 'install_hint_web.dart';

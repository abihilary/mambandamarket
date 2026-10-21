// The browser's own share sheet, for the web build. See web_share_web.dart.
export 'web_share_stub.dart'
    if (dart.library.js_interop) 'web_share_web.dart';

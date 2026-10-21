import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cross_file/cross_file.dart';

/// The browser's own file dialog, for the web build's Document option.
///
/// A plain `<input type="file">`, clicked from the tap that chose "Document",
/// so the browser treats it as the user's own gesture. The file comes back as a
/// `blob:` URL, which XFile reads like any other on the web.
Future<({XFile file, String name})?> pickDocument(String accept) {
  final done = Completer<({XFile file, String name})?>();
  final document = globalContext['document']! as JSObject;
  final input =
      document.callMethod<JSObject>('createElement'.toJS, 'input'.toJS);
  input['type'] = 'file'.toJS;
  input['accept'] = accept.toJS;

  void finish(({XFile file, String name})? value) {
    if (!done.isCompleted) done.complete(value);
  }

  void onChange(JSAny? _) {
    final files = input['files'] as JSObject?;
    final count = (files?['length'] as JSNumber?)?.toDartInt ?? 0;
    if (files == null || count == 0) return finish(null);
    final file = files.callMethod<JSObject>('item'.toJS, 0.toJS);
    final name = (file['name'] as JSString).toDart;
    final type = (file['type'] as JSString?)?.toDart ?? '';
    final url = (globalContext['URL']! as JSObject)
        .callMethod<JSString>('createObjectURL'.toJS, file)
        .toDart;
    finish((
      file: XFile(url, name: name, mimeType: type.isEmpty ? null : type),
      name: name,
    ));
  }

  input.callMethod<JSAny?>(
      'addEventListener'.toJS, 'change'.toJS, onChange.toJS);
  // Fired when the dialog is closed without a choice (recent browsers). Where
  // it is not, the future simply never completes, which costs nothing.
  input.callMethod<JSAny?>('addEventListener'.toJS, 'cancel'.toJS,
      ((JSAny? _) => finish(null)).toJS);
  input.callMethod<JSAny?>('click'.toJS);
  return done.future;
}

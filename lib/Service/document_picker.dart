import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

import 'document_picker_web_stub.dart'
    if (dart.library.js_interop) 'document_picker_web.dart' as web;

/// Picks a document (PDF, Word, Excel, plain text) with the platform picker.
///
/// Deliberately not `file_picker`: that package still applies its own Kotlin
/// Gradle Plugin, which the app's AGP 9 / built-in-Kotlin toolchain cannot
/// compile. The Android side is a few lines in MainActivity instead, talking
/// over this channel. Photos keep using image_picker.
class DocumentPicker {
  static const _channel = MethodChannel('mambanda/doc_picker');

  /// Android and the web — iOS ships with the App Store build, and the chat
  /// composer hides the Document option wherever this is false. The web uses
  /// the browser's own file dialog.
  ///
  /// The web check comes first and is not incidental: `Platform.isAndroid`
  /// reads `dart:io`, which in a browser is a stub that throws. Asking it on
  /// the web build crashed the composer before it could hide anything.
  /// `defaultTargetPlatform` answers the same question without dart:io.
  static bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// The same kinds the Android picker offers.
  static const _accept = '.pdf,.doc,.docx,.xls,.xlsx,.txt,'
      'application/pdf,application/msword,text/plain,'
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document,'
      'application/vnd.ms-excel,'
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// The chosen file staged on disk plus its original name, or null if the
  /// user backed out.
  static Future<({XFile file, String name})?> pick() async {
    if (!isSupported) return null;
    if (kIsWeb) return web.pickDocument(_accept);
    final picked = await _channel.invokeMapMethod<String, String>('pick');
    final path = picked?['path'];
    final name = picked?['name'];
    if (path == null || name == null) return null;
    return (file: XFile(path, name: name), name: name);
  }
}

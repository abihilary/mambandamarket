import 'dart:io';

import 'package:flutter/services.dart';

/// Picks a document (PDF, Word, Excel, plain text) with the platform picker.
///
/// Deliberately not `file_picker`: that package still applies its own Kotlin
/// Gradle Plugin, which the app's AGP 9 / built-in-Kotlin toolchain cannot
/// compile. The Android side is a few lines in MainActivity instead, talking
/// over this channel. Photos keep using image_picker.
class DocumentPicker {
  static const _channel = MethodChannel('mambanda/doc_picker');

  /// Android only for now — iOS ships with the App Store build, and the chat
  /// composer hides the Document option wherever this is false.
  static bool get isSupported => Platform.isAndroid;

  /// The chosen file staged on disk plus its original name, or null if the
  /// user backed out.
  static Future<({File file, String name})?> pick() async {
    if (!isSupported) return null;
    final picked = await _channel.invokeMapMethod<String, String>('pick');
    final path = picked?['path'];
    final name = picked?['name'];
    if (path == null || name == null) return null;
    return (file: File(path), name: name);
  }
}

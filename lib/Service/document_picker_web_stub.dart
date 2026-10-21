import 'package:cross_file/cross_file.dart';

/// Only the web build has a browser dialog to open.
Future<({XFile file, String name})?> pickDocument(String accept) async => null;

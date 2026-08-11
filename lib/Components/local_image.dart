import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Showing a picture the user just picked, before it has been uploaded.
///
/// A browser has no filesystem. `dart:io`'s File compiles on web only as a stub
/// that throws the moment you touch it, so `Image.file` — which every dashboard
/// reached for — is a runtime crash there. What a web picker hands back instead
/// is a `blob:` URL, which the browser loads over the network like any other
/// image.
///
/// Both branches are written out rather than hidden behind conditional imports
/// because the difference is one line, and `File` is never constructed on web:
/// the [kIsWeb] check short-circuits before it is evaluated.
ImageProvider localImageProvider(String path) =>
    kIsWeb ? NetworkImage(path) : FileImage(File(path));

/// [Image.file] that also works in a browser.
///
/// Same arguments as the `Image.file` calls it replaces, so the dashboards read
/// the way they did before.
class LocalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  const LocalImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) => Image(
        image: localImageProvider(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
}

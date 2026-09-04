import 'package:flutter/material.dart';

/// Stands in for a photo that is missing, still loading, or failed.
///
/// Was a `Colors.grey.shade200` box with a grey icon, copy-pasted into three
/// profile screens. On a dark ground that is a pale slab in the middle of the
/// grid — brighter than the photos around it, and the one thing on screen that
/// never got the memo about the theme.
class ImagePlaceholder extends StatelessWidget {
  final double? size;
  final IconData icon;

  const ImagePlaceholder({super.key, this.size, this.icon = Icons.broken_image});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}

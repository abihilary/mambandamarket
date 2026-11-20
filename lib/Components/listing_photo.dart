import 'dart:collection';

import 'package:flutter/material.dart';

/// The shape a listing photo is drawn in, given the width it is offered.
///
/// Pinterest-style: every photo in a column or a rail is the same width, and
/// its height follows the photo's own proportions. A photo more extreme than
/// [minRatio] (too tall) or [maxRatio] (too wide) is not squeezed or
/// letterboxed: the box stops at the limit and the photo is cropped, anchored
/// to its top, so a tall photo loses its bottom and a wide one loses its sides.
@immutable
class PhotoShape {
  const PhotoShape({
    this.minRatio = 2 / 3,
    this.maxRatio = 4 / 3,
    this.fallbackRatio = 1,
  }) : assert(minRatio > 0 && minRatio <= maxRatio),
       assert(fallbackRatio >= minRatio && fallbackRatio <= maxRatio);

  /// Width over height of the tallest box allowed. 2/3 is a 2:3 portrait.
  final double minRatio;

  /// Width over height of the widest box allowed.
  final double maxRatio;

  /// The box used before the photo's size is known, and when it fails.
  final double fallbackRatio;

  /// The feed: tall portraits up to 2:3, wide shots down to 4:3.
  static const feed = PhotoShape();

  /// Horizontal rails, where every extra pixel of height is paid for by the
  /// whole row: 4:5 at the tallest.
  static const rail = PhotoShape(minRatio: 4 / 5, maxRatio: 3 / 2);

  double clamp(double? ratio) =>
      (ratio ?? fallbackRatio).clamp(minRatio, maxRatio).toDouble();

  /// The tallest this box can be at [width] — what a rail reserves.
  double maxHeightFor(double width) => width / minRatio;
}

/// Width over height of photos we have already decoded, so a card scrolled
/// back into view is the right height on its first frame instead of starting
/// square and jumping. Bounded, oldest out first.
class PhotoRatios {
  PhotoRatios._();

  static const _capacity = 600;
  // A LinkedHashMap keeps insertion order, which makes it an LRU for free.
  static final LinkedHashMap<Object, double> _ratios = LinkedHashMap();

  static double? of(Object key) => _ratios[key];

  static void remember(Object key, double ratio) {
    _ratios.remove(key);
    _ratios[key] = ratio;
    if (_ratios.length > _capacity) _ratios.remove(_ratios.keys.first);
  }

  @visibleForTesting
  static void clear() => _ratios.clear();
}

/// A listing photo whose height follows its proportions, within [shape].
///
/// Needs a bounded width (a grid cell, a rail card, a column) and sizes its
/// own height from it, so it is safe in unbounded-height parents — a masonry
/// column, a Column, a horizontally scrolling Row.
///
/// The size comes from the decoded image itself, through the same
/// [ImageStream] the [Image] below paints from, so the file is fetched and
/// decoded once. The listener is removed when the photo changes or the widget
/// goes away: a listener left on a cached stream keeps the whole State alive
/// and calls setState on it after it is gone.
class ListingPhoto extends StatefulWidget {
  const ListingPhoto({
    super.key,
    required this.image,
    this.shape = PhotoShape.feed,
    this.background,
  });

  final ImageProvider image;
  final PhotoShape shape;

  /// Shown while the photo loads, and in place of one that failed.
  final Color? background;

  @override
  State<ListingPhoto> createState() => _ListingPhotoState();
}

class _ListingPhotoState extends State<ListingPhoto> {
  ImageStream? _stream;
  late final ImageStreamListener _listener =
      ImageStreamListener(_onImage, onError: _onError);
  double? _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = PhotoRatios.of(widget.image);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ListingPhoto old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _ratio = PhotoRatios.of(widget.image);
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final w = info.image.width, h = info.image.height;
    info.dispose();
    if (h <= 0) return;
    final ratio = w / h;
    PhotoRatios.remember(widget.image, ratio);
    if (!mounted || ratio == _ratio) return;
    if (synchronousCall) {
      // Delivered during didChangeDependencies: build has not run yet, so
      // the field is enough and setState would be an error.
      _ratio = ratio;
    } else {
      setState(() => _ratio = ratio);
    }
  }

  void _onError(Object _, StackTrace? _) {}

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background =
        widget.background ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return AspectRatio(
      aspectRatio: widget.shape.clamp(_ratio),
      child: ColoredBox(
        color: background,
        child: Image(
          image: widget.image,
          // The box already has the photo's proportions; cover only crops
          // where the shape's limits cut in. Top-anchored, so it is the
          // bottom of a tall photo that goes.
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

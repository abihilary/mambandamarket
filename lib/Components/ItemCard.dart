import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/listing_presentation.dart';
import '../api/models.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'listing_photo.dart';

/// What a card says about [item] beyond its title and photo, from the
/// listing's own answers: the mode-aware price ("Dès 18.000 FCFA", "75.000
/// FCFA / mois"), the muted "nég." after it, the spec line ("Batt. 88 % ·
/// Occasion") and the kind or "Gratuit" pill.
///
/// One function so the feed, search, related items and the seller page cannot
/// drift apart. [withSpec] off is for the compact rail, which has no room.
({String price, String? priceTail, String? specLine, String? badge}) cardText(
  BuildContext context,
  Listing item,
  List<Category> categories, {
  bool withSpec = true,
}) {
  final l10n = context.l10n;
  final guide = guideFor(categories, item.categorySlug);
  final price = priceLine(item, guide, l10n, compact: true);
  final spec = withSpec
      ? specParts(
          item,
          attributeFieldsFor(categories, item.categorySlug),
          guide,
          l10n,
          Localizations.localeOf(context),
        ).join(' \u00b7 ')
      : '';
  return (
    price: price.main,
    priceTail: price.tail,
    specLine: spec.isEmpty ? null : spec,
    badge: switch (item.kind) {
      'service' => l10n.listingKindService,
      'job' => l10n.listingKindJob,
      _ => item.priceMode == 'free' ? l10n.priceFree : null,
    },
  );
}

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String? priceAddon;

  /// The listing's facts in one muted line between title and price ("Batt.
  /// 88 % · Occasion"). Null draws nothing; the grid keeps its height either way.
  final String? specLine;

  /// Muted words after the price — the "nég." of a negotiable amount.
  final String? priceTail;

  /// A pill on the photo's top-left: the kind of a service or job, or
  /// "Gratuit". Only what the listing really is — never a delivery promise.
  final String? badge;

  /// Where the item is, as the seller typed it. Null or blank renders nothing
  /// rather than an empty pin — most listings published before this existed
  /// have no location and should not all sprout a bare icon.
  final String? location;

  /// How far the item is from the buyer, in metres, when the feed was asked
  /// for a position. Null whenever we do not know — either the buyer has not
  /// shared a location or this listing carries none — and null renders
  /// nothing, for the same reason a blank city renders nothing.
  final double? distanceMeters;
  final bool isCompact;

  /// How the photo is shaped. Null is a square photo, for grids whose rows
  /// have a fixed height ([gridDelegate]). A shape gives a photo whose height
  /// follows the image, for parents that let the card choose its own height:
  /// a masonry column or a rail that aligns cards to the top. Never pass one
  /// inside a fixed-extent grid cell — the card would outgrow the cell.
  final PhotoShape? photoShape;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  const ItemCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.price,
    this.priceAddon,
    this.specLine,
    this.priceTail,
    this.badge,
    this.location,
    this.distanceMeters,
    this.isCompact = false,
    this.photoShape,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  }) : super(key: key);

  /// Columns for a width: as many as keep a card under [maxTileWidth], two at
  /// the least. Shared by the fixed grids and the home masonry, so a phone
  /// gets two and a tablet four everywhere.
  static int columnsFor(double crossAxisExtent, {double maxTileWidth = 200}) =>
      (crossAxisExtent / maxTileWidth).ceil().clamp(2, 8);

  /// Grid columns from the width, and a row height from the card itself: a
  /// square photo plus an allowance for two title lines, the spec line, the
  /// price and the city that grows with the reader's text size. For cards
  /// without a [photoShape] only.
  static SliverGridDelegate gridDelegate(
    double crossAxisExtent,
    TextScaler scaler, {
    double maxTileWidth = 200,
    double spacing = 14,
    double runSpacing = 18,
  }) {
    final n = columnsFor(crossAxisExtent, maxTileWidth: maxTileWidth);
    final tile = (crossAxisExtent - spacing * (n - 1)) / n;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: n,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      mainAxisExtent: tile + 4 + scaler.scale(96),
    );
  }

  /// "350 m" under a kilometre, "2,3 km" above it.
  String _distanceLabel(BuildContext context, double metres) {
    if (metres < 1000) return '${metres.round()} m';
    final locale = Localizations.localeOf(context).toString();
    return '${NumberFormat('0.#', locale).format(metres / 1000)} km';
  }

  /// Where a card's photo comes from. A seam for tests, which have no disk
  /// cache for the network provider to open.
  @visibleForTesting
  static ImageProvider Function(String url) imageFor =
      CachedNetworkImageProvider.new;

  /// Width of a compact card in a horizontal rail.
  static const compactWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = distanceMeters;
    final image = imageFor(imageUrl);
    final shape = photoShape;

    return Tappable(
      onTap: onTap,
      child: Container(
        width: isCompact ? compactWidth : double.infinity,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image with rounded corners & optional heart badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: shape != null
                      ? ListingPhoto(image: image, shape: shape)
                      : AspectRatio(
                          aspectRatio: 1,
                          child: ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Image(
                              image: image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.expand(),
                            ),
                          ),
                        ),
                ),
                if (badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                if (!isCompact && onFavoriteToggle != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Tappable(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color:
                              isFavorite ? AppColors.danger : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // No Flexible here: a flex child asks its Column for bounded
            // height, and a masonry column or a top-aligned rail has none.
            // The text is capped by maxLines instead, and fixed-height grids
            // size their rows for it (see gridDelegate).
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                  if (specLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      specLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // Flexible, so "3.500.000 FCFA nég." in a 140px card
                      // ellipsises instead of overflowing the row.
                      Flexible(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (priceTail != null && priceTail!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          priceTail!,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (location != null && location!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 11, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            distance != null
                                ? '${location!.trim()} \u00b7 ${_distanceLabel(context, distance)}'
                                : location!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

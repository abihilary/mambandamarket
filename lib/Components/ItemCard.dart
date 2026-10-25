import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/listing_presentation.dart';
import '../api/models.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

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
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  }) : super(key: key);

  /// Grid columns from the width, and a row height from the card itself.
  ///
  /// `childAspectRatio` scaled the text block with the photo, so a wide tile
  /// got empty space and a narrow one, or a large text size, overflowed. Here
  /// the photo is square at whatever width the columns leave, and the text
  /// below it gets a fixed allowance — two title lines, the spec line, the
  /// price and the city — that grows with the reader's text size.
  static SliverGridDelegate gridDelegate(
    double crossAxisExtent,
    TextScaler scaler, {
    double maxTileWidth = 200,
    double spacing = 14,
    double runSpacing = 18,
  }) {
    final n = (crossAxisExtent / maxTileWidth).ceil().clamp(2, 8);
    final tile = (crossAxisExtent - spacing * (n - 1)) / n;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: n,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      // title 2 lines + spec + price + city
      mainAxisExtent: tile + 4 + scaler.scale(96),
    );
  }

  /// "350 m" under a kilometre, "2,3 km" above it.
  ///
  /// No translated unit: m and km are the same word in both languages we ship,
  /// and the separator follows the locale through NumberFormat.
  String _distanceLabel(BuildContext context, double metres) {
    if (metres < 1000) return '${metres.round()} m';
    final locale = Localizations.localeOf(context).toString();
    return '${NumberFormat('0.#', locale).format(metres / 1000)} km';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = distanceMeters;

    return Tappable(
      onTap: onTap,
      child: Container(
        width: isCompact ? 140 : double.infinity,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Prevents forced stretching
          children: [
            // Image with rounded corners & optional heart badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Image(
                      image: CachedNetworkImageProvider(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: scheme.surfaceContainerHighest),
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
                // A heart with nothing behind it is a control that lies. It
                // shows only where the caller has somewhere for the tap to go
                // — the compact rail never did, and now neither does any
                // screen that omits the callback.
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
            // Flexible wrapper around text prevents bottom overflow
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12, // Reduced slightly for compact fitting
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
                  // Price & Addon
                  Row(
                    children: [
                      // Flexible, so "3.500.000 FCFA nég." in a 140px card
                      // ellipsises instead of overflowing the tile.
                      Flexible(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            // The deck prices in the brand accent, not in green.
                            // accentInk rather than the fill, because this is
                            // text on the page: raw lime is 1.4:1 on white.
                            color: context.tokens.accentInk,
                          ),
                        ),
                      ),
                      if (priceTail != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          priceTail!,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (priceAddon != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          priceAddon!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.tokens.accentInk,
                          ),
                        ),
                      ]
                    ],
                  ),
                  if ((location != null && location!.trim().isNotEmpty) ||
                      distance != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        // One line, ellipsised. A compact card is 140px wide
                        // and "Cité des Palmiers, Douala" does not fit; a
                        // second line would push the price out of the grid
                        // cell and overflow every tile in the row.
                        Expanded(
                          child: Text(
                            [
                              if (location != null && location!.trim().isNotEmpty)
                                location!.trim(),
                              if (distance != null)
                                _distanceLabel(context, distance),
                            ].join(' \u00b7 '),
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
            ),
          ],
        ),
      ),
    );
  }
}
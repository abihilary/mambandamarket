import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String? priceAddon;

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
    this.location,
    this.distanceMeters,
    this.isCompact = false,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  }) : super(key: key);

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

    return GestureDetector(
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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: scheme.surfaceContainerHighest),
                    ),
                  ),
                ),
                if (!isCompact)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
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
                  const SizedBox(height: 2),
                  // Price & Addon
                  Row(
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          // The deck prices in the brand accent, not in green.
                          // accentInk rather than the fill, because this is
                          // text on the page: raw lime is 1.4:1 on white.
                          color: context.tokens.accentInk,
                        ),
                      ),
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
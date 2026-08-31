import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String? priceAddon;

  /// Where the item is, as the seller typed it. Null or blank renders nothing
  /// rather than an empty pin — most listings published before this existed
  /// have no location and should not all sprout a bare icon.
  final String? location;
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
    this.isCompact = false,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          // Routed through the token so the price stays legible
                          // on a dark ground as well as a light one.
                          color: AppColors.success,
                        ),
                      ),
                      if (priceAddon != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          priceAddon!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ]
                    ],
                  ),
                  if (location != null && location!.trim().isNotEmpty) ...[
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
                            location!.trim(),
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
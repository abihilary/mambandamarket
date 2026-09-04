import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Amber that can be read on the ground it lands on.
///
/// `Colors.amber` is 2.27:1 on white — fine as an icon, unreadable as a label,
/// which is exactly how it was being used. The dark value is the semantic
/// [AppColors.warning] (8.1:1 on the dark surface); the light one is deepened
/// to 5.5:1 on white.
Color ratingInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.warning
        : const Color(0xFF8A6200);

/// A seller's star rating.
///
/// Renders nothing at all when there are no reviews. Most listings will have
/// none for a long time and should not each sprout a bare star — the same
/// reason ItemCard hides an empty location pin.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int count;

  /// Compact drops the review count, for places as tight as a feed card.
  final bool compact;

  const RatingBadge({
    super.key,
    required this.rating,
    required this.count,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final ink = ratingInk(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: isDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: ink),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: TextStyle(fontSize: 10, color: ink),
            ),
          ],
        ],
      ),
    );
  }
}

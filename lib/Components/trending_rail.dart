import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/trending_model.dart';
import '../api/trending_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'ItemCard.dart';
import 'home_board.dart';

/// The curated product row under the promo section.
///
/// Renders nothing at all when there is nothing to show — no heading, no
/// padding, no skeleton. A placeholder that resolves to nothing is a hole in
/// the feed with a countdown on it, and "there is nothing trending" is the
/// normal answer here rather than a failure worth explaining.
///
/// The server decides whether the row exists. This widget only draws what it
/// was given.
class TrendingRail extends StatelessWidget {
  const TrendingRail({super.key, required this.onOpen, this.onCategory});

  /// Opening a product is left to the feed, so ItemDetailScreen is still
  /// constructed in one place — and so a listing already in hand is not sent
  /// back through a fetch-by-id to be opened.
  final void Function(Listing) onOpen;

  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrendingSection?>(
      valueListenable: TrendingRepository.instance.section,
      builder: (context, section, _) {
        if (section == null || section.items.isEmpty) {
          return const SizedBox.shrink();
        }

        final locale = Localizations.localeOf(context);
        final title = section.titleFor(locale) ?? context.l10n.trendingTitle;
        final seeAll = section.seeAll;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // The same header geometry as the gallery rail below, so the two
              // read as siblings rather than as two different ideas.
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (seeAll != null)
                    TextButton(
                      onPressed: () =>
                          openBoardLink(context, seeAll, onCategory: onCategory),
                      style: TextButton.styleFrom(
                        foregroundColor: context.tokens.accentInk,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(context.l10n.homeSeeAll),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 218,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: section.items.length,
                itemBuilder: (context, index) {
                  final item = section.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ItemCard(
                      imageUrl: item.primaryImageUrl,
                      title: item.title,
                      price: item.displayPrice,
                      location: item.city,
                      // The compact card draws no heart, so there is no
                      // favourites listener rebuilding this row.
                      isCompact: true,
                      onTap: () => onOpen(item),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

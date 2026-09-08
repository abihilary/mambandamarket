import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/trending_model.dart';
import '../api/trending_repository.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'VerifiedBadge.dart';
import 'home_board.dart';
import 'image_placeholder.dart';

/// What people are actually looking at right now.
///
/// A bigger card than the gallery rail's, because this row has a job the
/// gallery does not: saying *why* something is here. A rank, how many people
/// saved it, how many opened it, when it went up, and who is selling it.
///
/// Every number on this card is one this product genuinely collects. There is
/// no comments table and no offers table in this system, so there are no
/// comment counts and no "make an offer" — a card inventing either would be
/// showing engagement nobody generated, on somebody's real listing.
///
/// Renders nothing at all when there is nothing to show: no heading, no
/// skeleton. A placeholder that resolves to nothing is a hole with a countdown
/// on it.
class TrendingRail extends StatefulWidget {
  const TrendingRail({
    super.key,
    required this.onOpen,
    this.onCategory,
    this.categorySlug,
    this.onMessage,
  });

  final void Function(Listing) onOpen;
  final void Function(String slug)? onCategory;

  /// The category the feed is filtered to, if any.
  final String? categorySlug;

  /// Opening a chat with the seller, which is how an offer is actually made
  /// here — there is no offer feature to point at.
  final void Function(Listing)? onMessage;

  @override
  State<TrendingRail> createState() => _TrendingRailState();
}

enum _Tab { now, near, forYou }

class _TrendingRailState extends State<TrendingRail> {
  _Tab _tab = _Tab.now;

  Future<void> _select(_Tab tab) async {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    await TrendingRepository.instance.load(
      categorySlug: widget.categorySlug,
      nearMe: tab == _Tab.near,
      likeMyFavourites: tab == _Tab.forYou,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrendingSection?>(
      valueListenable: TrendingRepository.instance.section,
      builder: (context, section, _) {
        final l10n = context.l10n;
        final locale = Localizations.localeOf(context);

        // The tabs stay put once the row exists, so switching to one that
        // happens to be empty does not make the whole thing vanish under the
        // finger that tapped it.
        final items = section?.items ?? const <Listing>[];
        if (section == null && _tab == _Tab.now) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section?.titleFor(locale) ?? l10n.trendingTitle,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (section?.seeAll != null)
                    TextButton(
                      onPressed: () => openBoardLink(context, section!.seeAll!,
                          onCategory: widget.onCategory),
                      style: TextButton.styleFrom(
                        foregroundColor: context.tokens.accentInk,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.homeSeeAll),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _TabChip(
                      label: l10n.trendTabNow,
                      selected: _tab == _Tab.now,
                      onTap: () => _select(_Tab.now)),
                  _TabChip(
                      label: l10n.trendTabNear,
                      selected: _tab == _Tab.near,
                      onTap: () => _select(_Tab.near)),
                  _TabChip(
                      label: l10n.trendTabForYou,
                      selected: _tab == _Tab.forYou,
                      onTap: () => _select(_Tab.forYou)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  l10n.shipPickerNoMatch,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 312,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TrendingCard(
                      item: items[i],
                      rank: i + 1,
                      onTap: () => widget.onOpen(items[i]),
                      onMessage: widget.onMessage == null
                          ? null
                          : () => widget.onMessage!(items[i]),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        // accentFill is a background and never ink: lime reads at 1.43:1 on
        // white, so the selected chip's label is onAccentFill.
        color: selected ? tokens.accentFill : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? tokens.onAccentFill : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.item,
    required this.rank,
    required this.onTap,
    this.onMessage,
  });

  final Listing item;
  final int rank;
  final VoidCallback onTap;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return SizedBox(
      width: 224,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: item.primaryImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ImagePlaceholder(),
                      errorWidget: (_, __, ___) => const ImagePlaceholder(),
                    ),
                  ),
                  // Rank. The whole reason somebody looks at this row is to
                  // know what is ahead of what.
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.accentFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🔥 #$rank',
                        style: TextStyle(
                          color: tokens.onAccentFill,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _age(l10n, item.createdAt),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Saves and views, in a rail down the image. Both are real
                  // counts; nothing here is invented.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(
                      children: [
                        _Stat(icon: Icons.favorite, value: item.favoriteCount),
                        const SizedBox(height: 6),
                        _Stat(icon: Icons.visibility_outlined, value: item.viewCount),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displayPrice,
                      style: TextStyle(
                        color: tokens.accentInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: scheme.surface,
                          backgroundImage: (item.sellerImageUrl?.isNotEmpty ?? false)
                              ? CachedNetworkImageProvider(item.sellerImageUrl!)
                              : null,
                          child: (item.sellerImageUrl?.isNotEmpty ?? false)
                              ? null
                              : Icon(Icons.person, size: 12, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.sellerLabel ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ),
                        // A real badge for a real check. Not a green "online"
                        // dot: nothing in this system knows who is online.
                        if (item.sellerVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(dense: true, size: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _CardButton(
                            label: item.isBuyable ? l10n.trendBuy : l10n.trendMessage,
                            filled: item.isBuyable,
                            onTap: item.isBuyable ? onTap : (onMessage ?? onTap),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _age(AppLocalizations l10n, DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inHours < 1) return l10n.trendJustNow;
    if (d.inHours < 24) return l10n.trendHoursAgo(d.inHours);
    return l10n.trendDaysAgo(d.inDays);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _compact(value),
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// 2400 → 2.4K. Long numbers do not fit a pill this size, and nobody reads
  /// the last two digits of a view count anyway.
  static String _compact(int n) {
    if (n < 1000) return '$n';
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}K';
    if (n < 1000000) return '${(n / 1000).round()}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? tokens.accentFill : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: filled
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? tokens.onAccentFill : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

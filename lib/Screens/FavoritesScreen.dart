import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../Components/ItemDetailScreen.dart';
import '../Components/saved_note.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../Components/shipping_button.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

/// Saved listings, grouped by what they are.
///
/// This screen used to be a flat list of rows with no `onTap` — you could save
/// an item and then do nothing whatsoever with it, including look at it. The
/// heart was the only working control on the page. Now a row opens the same
/// detail screen the feed opens, and the list is grouped, because a favourites
/// list is a shortlist and a shortlist is read by kind: the three phones
/// together, then the two guitars.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = FavoritesRepository.instance;

  /// Only while there is nothing to show yet: the list restored from the
  /// device at launch stays on screen while the network revalidates it.
  late bool _isLoading;

  /// Nothing was ever loaded and the first load failed. Without this the
  /// screen said "no favourites yet" to somebody who simply had no signal.
  bool _failed = false;

  /// Slug → category, for the section headings. Purely cosmetic: without it the
  /// headings fall back to the slug, which is readable if ugly, so a failed
  /// load never costs the screen anything.
  Map<String, Category> _categories = {};

  @override
  void initState() {
    super.initState();
    _isLoading = _nothingShown;
    final saved = ListingsRepository.instance.savedCategories();
    if (saved != null) _categories = {for (final c in saved.value) c.slug: c};
    _load();
    _loadCategories();
  }

  bool get _nothingShown => !_repo.loadedOnce && _repo.favorites.value.isEmpty;

  /// [userAsked]: a pull. It says why it failed; a background load keeps the
  /// list and stays quiet.
  Future<void> _load({bool userAsked = false}) async {
    if (_nothingShown) {
      setState(() {
        _isLoading = true;
        _failed = false;
      });
    }
    try {
      await _repo.refresh();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failed = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_nothingShown) {
        setState(() {
          _failed = true;
          _isLoading = false;
        });
        return;
      }
      // The list on screen stays.
      setState(() => _isLoading = false);
      if (userAsked) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  String _errorText(Object e) {
    final l10n = context.l10n;
    if (e is! ApiException) return l10n.errorUnexpected;
    if (e.isNetwork) return l10n.connectionError;
    if (e.isTimeout) return l10n.errorTimeout;
    if (e.isBadResponse) return l10n.errorBadResponse;
    return e.message;
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ListingsRepository.instance.categories();
      if (!mounted) return;
      setState(() => _categories = {for (final c in cats) c.slug: c});
    } catch (_) {
      // Headings fall back to slugs.
    }
  }

  /// Which section a listing belongs in.
  ///
  /// The root, not the leaf: a listing filed under "Guitars" shows up beside
  /// the rest of the music, which matches the vocabulary of the category strip
  /// on the home feed. Listings published before the tree existed sit on roots
  /// already, so both generations group the same way.
  String? _sectionSlug(Listing item) {
    final slug = item.categorySlug;
    if (slug.isEmpty) return null;
    final category = _categories[slug];
    if (category == null) return slug;
    return category.parentSlug ?? category.slug;
  }

  String _sectionLabel(BuildContext context, String? slug) {
    if (slug == null) return context.l10n.favoritesOtherCategory;
    final category = _categories[slug];
    if (category == null) return slug;
    return category.displayLabel(Localizations.localeOf(context));
  }

  /// Sections in the server's own category order, with the uncategorised bucket
  /// last. Sorting by label instead would reorder the whole screen when the
  /// language changes, which is a strange thing for a shortlist to do.
  List<(String?, List<Listing>)> _sections(List<Listing> favorites) {
    final buckets = <String?, List<Listing>>{};
    for (final item in favorites) {
      buckets.putIfAbsent(_sectionSlug(item), () => []).add(item);
    }
    final order = _categories.keys.toList();
    final keys = buckets.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
    return [for (final k in keys) (k, buckets[k]!)];
  }

  Future<void> _openDetail(Listing item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          title: item.title,
          price: item.displayPrice,
          imageUrl: item.primaryImageUrl,
          images: item.imageUrls,
          listingId: item.id,
          listing: item,
        ),
      ),
    );
    // Unfavouriting from the detail screen has to be reflected here, or the
    // item stays on a list it is no longer on.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.instance.session != null;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoritesTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: !signedIn
          ? Center(
              child: Text(l10n.signInToSeeFavorites,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _failed
                  ? _FailedView(onRetry: _load)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The list is what this device saved, and why it
                        // could not be refreshed. Nothing when the server
                        // answered.
                        ValueListenableBuilder<SavedReason?>(
                          valueListenable: _repo.savedReason,
                          builder: (context, reason, _) =>
                              SavedNote(reason: reason),
                        ),
                        Expanded(child: _favoritesList(context)),
                      ],
                    ),
    );
  }

  Widget _favoritesList(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<Listing>>(
      valueListenable: _repo.favorites,
      builder: (context, favorites, _) {
        if (favorites.isEmpty) {
          // Scrollable, so the empty state can still be pulled to
          // refresh — a saved item added on another device has no
          // other way of appearing.
          return RefreshIndicator(
            onRefresh: () => _load(userAsked: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: Center(
                    child: Text(l10n.noFavoritesYet,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ),
          );
        }

        final sections = _sections(favorites);
        return RefreshIndicator(
          onRefresh: () => _load(userAsked: true),
          child: ListView(
            // Clearance for the docked publish button, and for
            // the shipping button sitting above it.
            // Centred on a desktop, where the rows also go two
            // or three across instead of one 1400px row each.
            padding: frameInsets(
              context,
              maxWidth: Breakpoints.dashboard,
              min: 16,
            ).copyWith(
              top: 8,
              bottom: shippingButtonClearance(context),
            ),
            children: [
              for (final (slug, items) in sections) ...[
                _SectionHeading(
                  label: _sectionLabel(context, slug),
                  count: items.length,
                ),
                _RowColumns(
                  children: [
                    for (final item in items)
                      _FavoriteRow(
                        item: item,
                        onTap: () => _openDetail(item),
                        onRemove: () => _repo.toggle(item.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The first load failed with nothing saved to show instead.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              context.l10n.connectionError,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// One column of rows on a phone; as many 360px columns as fit beside the
/// desktop sidebar.
class _RowColumns extends StatelessWidget {
  const _RowColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 360).floor().clamp(1, 3);
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeading({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final Listing item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteRow({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final city = item.city?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: CachedNetworkImageProvider(item.primaryImageUrl),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displayPrice,
                      // The brand accent, as on every other price in the app.
                      // This was AppColors.success — a green that appears
                      // nowhere else and read as a status rather than a price.
                      style: TextStyle(
                        color: tokens.accentInk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (city != null && city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: AppColors.danger),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

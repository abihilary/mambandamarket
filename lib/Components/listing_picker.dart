import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'image_placeholder.dart';

/// Ask somebody to pick a listing, and hand back the whole thing.
///
/// The whole [Listing] rather than an id, so a caller can fill in a title, a
/// price, a city and a category without a second round trip.
///
/// Null means the sheet was dismissed — "no change", not "cleared", the same
/// contract [showCategoryPicker] has.
Future<Listing?> showListingPicker(BuildContext context) {
  return showModalBottomSheet<Listing>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ListingPickerSheet(),
  );
}

class _ListingPickerSheet extends StatefulWidget {
  const _ListingPickerSheet();

  @override
  State<_ListingPickerSheet> createState() => _ListingPickerSheetState();
}

class _ListingPickerSheetState extends State<_ListingPickerSheet> {
  final _controller = TextEditingController();
  final _repo = ListingsRepository.instance;

  Timer? _debounce;
  int _requestId = 0;
  bool _loading = false;
  String _query = '';
  List<Listing> _results = const [];

  @override
  void initState() {
    super.initState();
    // Nothing on screen until they type would waste the most likely answer:
    // favourites are already in memory, and somebody who saved a phone last
    // week is exactly who asks us to ship one.
    final saved = FavoritesRepository.instance.favorites.value;
    if (saved.isEmpty) _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    // A slow request for "ph" must not land on top of a fast one for "phone".
    final mine = ++_requestId;
    setState(() {
      _query = query;
      _loading = true;
    });
    try {
      final items = await _repo.browse(query: query.isEmpty ? null : query, limit: 30);
      if (!mounted || mine != _requestId) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || mine != _requestId) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final saved = FavoritesRepository.instance.favorites.value;
    final showingFavourites = _query.isEmpty && saved.isNotEmpty;
    final items = showingFavourites ? saved : _results;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shipPickerTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.shipPickerSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                showingFavourites ? l10n.shipPickerFavorites : l10n.shipPickerSuggested,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          l10n.shipPickerNoMatch,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _Row(
                          item: items[i],
                          onTap: () => Navigator.pop(context, items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});

  final Listing item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: item.primaryImageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ImagePlaceholder(size: 56),
          errorWidget: (_, __, ___) => const ImagePlaceholder(size: 56),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(
            item.displayPrice,
            style: TextStyle(
              color: context.tokens.accentInk,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if ((item.city ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.place_outlined, size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                item.city!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

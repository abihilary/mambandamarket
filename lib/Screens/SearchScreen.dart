import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Components/ItemCard.dart';
import '../Components/ItemDetailScreen.dart';
import '../Components/category_picker.dart';
import '../api/api_client.dart';
import '../api/listing_attributes.dart';
import '../api/listing_presentation.dart';
import '../api/location_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../Components/safe_bottom.dart';
import '../Components/require_account.dart';
import '../theme/breakpoints.dart';

/// Everything the query is narrowed by.
///
/// One object rather than six fields on the state, so "are any filters on" and
/// "clear them" are each one line, and so a sheet can hand back a whole new set
/// without the caller unpacking it.
@immutable
class SearchFilters {
  final String? categorySlug;
  final int? minCents;
  final int? maxCents;
  final String? condition;
  final String sort;
  final bool nearMe;

  /// Details of the chosen category to match, by field key: {'sizes': 'M'}.
  /// Meaningless without that category, so changing it clears these.
  final Map<String, String> attrs;

  const SearchFilters({
    this.attrs = const {},
    this.categorySlug,
    this.minCents,
    this.maxCents,
    this.condition,
    this.sort = 'recent',
    this.nearMe = false,
  });

  bool get isEmpty =>
      categorySlug == null &&
      minCents == null &&
      maxCents == null &&
      condition == null &&
      sort == 'recent' &&
      !nearMe &&
      attrs.isEmpty;

  SearchFilters copyWith({
    String? categorySlug,
    int? minCents,
    int? maxCents,
    String? condition,
    String? sort,
    bool? nearMe,
    Map<String, String>? attrs,
    bool clearCategory = false,
    bool clearPrice = false,
    bool clearCondition = false,
  }) => SearchFilters(
    categorySlug: clearCategory ? null : (categorySlug ?? this.categorySlug),
    minCents: clearPrice ? null : (minCents ?? this.minCents),
    maxCents: clearPrice ? null : (maxCents ?? this.maxCents),
    condition: clearCondition ? null : (condition ?? this.condition),
    sort: sort ?? this.sort,
    nearMe: nearMe ?? this.nearMe,
    attrs:
        clearCategory ||
            (categorySlug != null && categorySlug != this.categorySlug)
        ? (attrs ?? const {})
        : (attrs ?? this.attrs),
  );
}

/// Search, as its own place rather than a filter on the feed.
///
/// The home field used to narrow the feed in situ: you typed, the same grid
/// quietly became fewer items, and everything the API can actually search on —
/// price, condition, ordering, distance — was unreachable because there was
/// nowhere to put it. This is a surface of its own, so it can carry recents,
/// filters, a result count, and pages beyond the first.
class SearchScreen extends StatefulWidget {
  /// Pre-selected category, when arriving from a category the user already
  /// chose on the feed.
  final String? initialCategorySlug;

  /// Words to search for straight away — a place tapped on a listing.
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialCategorySlug,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _kRecentsKey = 'search_recents_v1';
  static const _kMaxRecents = 8;
  static const _pageSize = 30;

  /// The field's shape: rounded, with no line of its own. The theme fills it,
  /// and a fill with `InputBorder.none` is painted as a bare rectangle.
  static final OutlineInputBorder _pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: BorderSide.none,
  );

  final _repo = ListingsRepository.instance;
  final _favorites = FavoritesRepository.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _debounce;
  String _query = '';
  SearchFilters _filters = const SearchFilters();

  List<Category> _categories = [];
  List<String> _recents = [];

  final List<Listing> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;

  /// Guards against a slow first request landing after a faster later one and
  /// overwriting it — the classic way a search box ends up showing results for
  /// something the user has already typed past.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _filters = SearchFilters(categorySlug: widget.initialCategorySlug);
    final query = widget.initialQuery?.trim() ?? '';
    if (query.isNotEmpty) {
      _controller.text = query;
      _query = query;
    }
    _loadCategories();
    _loadRecents();
    _scrollController.addListener(_onScroll);
    // A category arriving from the feed, or a place from a listing, is
    // already a query worth running.
    if (widget.initialCategorySlug != null || query.isNotEmpty) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // The category filter simply stays unavailable.
    }
  }

  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _recents = prefs.getStringList(_kRecentsKey) ?? []);
    } catch (_) {}
  }

  /// Remembered only on a deliberate search — a submit, or a tap on a filter —
  /// never on every keystroke, or the list fills with the prefixes of one word.
  Future<void> _remember(String term) async {
    final value = term.trim();
    if (value.isEmpty) return;
    final next = [value, ..._recents.where((r) => r != value)]
        .take(_kMaxRecents)
        .toList();
    setState(() => _recents = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentsKey, next);
    } catch (_) {}
  }

  Future<void> _clearRecents() async {
    setState(() => _recents = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecentsKey);
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _run);
    setState(() {}); // the clear button
  }

  void _onScroll() {
    if (_loading || _loadingMore || _exhausted) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) _run(more: true);
  }

  bool get _hasCriteria => _query.trim().isNotEmpty || !_filters.isEmpty;

  Future<void> _run({bool more = false}) async {
    if (!_hasCriteria) {
      setState(() {
        _results.clear();
        _exhausted = true;
        _loading = false;
        _error = null;
      });
      return;
    }

    final id = ++_requestId;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _exhausted = false;
      }
      _error = null;
    });

    // Read synchronously, as the feed does: a denied permission must not turn
    // into a platform round trip in front of every search.
    final origin =
        _filters.nearMe ? LocationService.instance.cached : null;

    try {
      final items = await _repo.browse(
        query: _query.trim().isEmpty ? null : _query.trim(),
        categorySlug: _filters.categorySlug,
        minCents: _filters.minCents,
        maxCents: _filters.maxCents,
        condition: _filters.condition,
        attrs: _filters.attrs,
        lat: origin?.lat,
        lng: origin?.lng,
        // No radius, for the same reason the feed sends none: with almost no
        // listing carrying a coordinate, a radius empties the page rather than
        // narrowing it.
        sort: _filters.sort,
        limit: _pageSize,
        offset: more ? _results.length : 0,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        if (!more) _results.clear();
        _results.addAll(items);
        _exhausted = items.length < _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = context.l10n.couldNotLoadMessages;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _applyFilters(SearchFilters next) {
    setState(() => _filters = next);
    _remember(_query);
    _run();
  }

  void _submit(String value) {
    _debounce?.cancel();
    _controller.text = value;
    _query = value;
    _remember(value);
    _run();
  }

  Future<void> _toggleFavorite(Listing item) async {
    final l10n = context.l10n;
    if (!await requireAccount(context, l10n.favoriteSignInRequired)) return;
    try {
      await _favorites.toggle(item.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isUnauthorized
            ? l10n.favoriteSignInRequired
            : l10n.favoriteUpdateFailed),
      ));
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // The back arrow already sits close to the field, so the title keeps
        // no spacing of its own on the left; the right is padded instead,
        // because an AppBar with no actions runs its title to the very edge
        // and the field ended flush against the bezel.
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: l10n.homeSearchHint,
              // The theme fills fields with `surface`, which on the light
              // theme is the same white as the AppBar behind this one — the
              // pill disappeared and the text sat on nothing. A container
              // shade reads on both grounds.
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // Rounded and borderless rather than no border at all: with
              // InputBorder.none the theme's fill is painted as a bare
              // rectangle, which is what made the field read as a strip
              // stopping at the screen edge rather than as a field.
              border: _pill,
              enabledBorder: _pill,
              focusedBorder: _pill,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _FilterBar(
            filters: _filters,
            categories: _categories,
            onChanged: _applyFilters,
          ),
        ),
      ),
      body: ContentFrame(
        maxWidth: Breakpoints.feed,
        child: _body(context, l10n, scheme),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off,
        text: _error!,
        action: OutlinedButton(onPressed: _run, child: Text(l10n.retry)),
      );
    }
    if (!_hasCriteria) {
      return _RecentsView(
        recents: _recents,
        prompt: l10n.searchEmptyPrompt,
        onPick: _submit,
        onClear: _clearRecents,
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return _Message(
        icon: Icons.search_off,
        text: _query.trim().isEmpty
            ? l10n.searchNoResultsFiltered
            : l10n.searchNoResults(_query.trim()),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              // Honest about what it is: the number on this page, not a total
              // the endpoint never returns.
              l10n.searchResultsCount(_results.length),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          // Saving works here too. Finding something and having no way to keep
          // it is how the old favourites screen went wrong, one step earlier.
          sliver: ValueListenableBuilder<Set<String>>(
            valueListenable: _favorites.favoriteIds,
            builder: (context, favIds, _) => SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                // See the note on the feed's grid: the count comes from the
                // width so a wide screen gets more columns rather than bigger
                // cards.
                gridDelegate: ItemCard.gridDelegate(
                  constraints.crossAxisExtent,
                  MediaQuery.textScalerOf(context),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _results[index];
                    final card = cardText(context, item, _categories);
                    return ItemCard(
                      imageUrl: item.primaryImageUrl,
                      title: item.title,
                      price: card.price,
                      priceTail: card.priceTail,
                      specLine: card.specLine,
                      badge: card.badge,
                      location: item.city,
                      distanceMeters: item.distanceMeters,
                      isFavorite: favIds.contains(item.id),
                      onTap: () => _openDetail(item),
                      onFavoriteToggle: () => _toggleFavorite(item),
                    );
                  },
                  childCount: _results.length,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 96,
            child: _loadingMore
                ? const Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// The row of filter chips under the field.
class _FilterBar extends StatelessWidget {
  final SearchFilters filters;
  final List<Category> categories;
  final ValueChanged<SearchFilters> onChanged;

  const _FilterBar({
    required this.filters,
    required this.categories,
    required this.onChanged,
  });

  String _sortLabel(AppLocalizations l10n, String sort) => switch (sort) {
        'price_asc' => l10n.sortPriceLow,
        'price_desc' => l10n.sortPriceHigh,
        'distance' => l10n.sortNearest,
        _ => l10n.sortNewest,
      };

  String _priceLabel(AppLocalizations l10n) {
    final min = filters.minCents;
    final max = filters.maxCents;
    if (min == null && max == null) return l10n.filterPrice;
    if (min != null && max != null) {
      return '${formatPrice(min)} – ${formatPrice(max)}';
    }
    return min != null ? '${formatPrice(min)}+' : '≤ ${formatPrice(max!)}';
  }

  Future<void> _pickCategory(BuildContext context) async {
    if (categories.isEmpty) return;
    final picked = await showCategoryPicker(
      context,
      categories: categories,
      selectedSlug: filters.categorySlug,
    );
    if (picked == null) return;
    onChanged(filters.copyWith(categorySlug: picked));
  }

  Future<void> _pickAttr(BuildContext context, AttrField field) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final current = filters.attrs[field.key];
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  field.label(locale),
                  style: Theme.of(sheet).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final o in field.options)
                ListTile(
                  title: Text(o.label(locale)),
                  trailing: current == o.value
                      ? Icon(Icons.check, color: context.tokens.accentInk)
                      : null,
                  onTap: () => Navigator.pop(sheet, o.value),
                ),
              ListTile(
                title: Text(l10n.filterAny),
                onTap: () => Navigator.pop(sheet, ''),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    final next = Map<String, String>.from(filters.attrs);
    if (picked.isEmpty) {
      next.remove(field.key);
    } else {
      next[field.key] = picked;
    }
    onChanged(filters.copyWith(attrs: next));
  }

  Future<void> _pickCondition(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in const ['New', 'Like New', 'Used', 'Refurbished'])
              ListTile(
                title: Text(conditionLabel(l10n, c) ?? c),
                trailing: filters.condition == c
                    ? Icon(Icons.check, color: context.tokens.accentInk)
                    : null,
                onTap: () => Navigator.pop(sheet, c),
              ),
            ListTile(
              title: Text(l10n.filterAny),
              onTap: () => Navigator.pop(sheet, ''),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onChanged(picked.isEmpty
        ? filters.copyWith(clearCondition: true)
        : filters.copyWith(condition: picked));
  }

  Future<void> _pickSort(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in const [
              'recent',
              'price_asc',
              'price_desc',
              'distance'
            ])
              ListTile(
                title: Text(_sortLabel(l10n, s)),
                trailing: filters.sort == s
                    ? Icon(Icons.check, color: context.tokens.accentInk)
                    : null,
                onTap: () => Navigator.pop(sheet, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    // Sorting by distance without a position sorts by nothing at all, so it
    // turns the location on rather than silently doing nothing.
    onChanged(filters.copyWith(
      sort: picked,
      nearMe: picked == 'distance' ? true : filters.nearMe,
    ));
  }

  Future<void> _pickPrice(BuildContext context) async {
    final result = await showModalBottomSheet<List<int?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _PriceSheet(
        minCents: filters.minCents,
        maxCents: filters.maxCents,
      ),
    );
    if (result == null) return;
    onChanged(filters
        .copyWith(clearPrice: true)
        .copyWith(minCents: result[0], maxCents: result[1]));
  }

  Future<void> _toggleNearMe(BuildContext context) async {
    if (filters.nearMe) {
      onChanged(filters.copyWith(
        nearMe: false,
        sort: filters.sort == 'distance' ? 'recent' : filters.sort,
      ));
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await LocationService.instance.refresh();
    final usable = outcome == LocationOutcome.ok ||
        LocationService.instance.cached != null;
    if (usable) {
      onChanged(filters.copyWith(nearMe: true));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(switch (outcome) {
        LocationOutcome.servicesOff => l10n.locationServicesOff,
        LocationOutcome.deniedForever => kIsWeb ? l10n.locationDeniedWeb : l10n.locationDeniedForever,
        LocationOutcome.denied => l10n.locationDenied,
        _ => l10n.locationUnavailable,
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final category = filters.categorySlug == null
        ? null
        : categories
            .where((c) => c.slug == filters.categorySlug)
            .map((c) => c.displayLabel(locale))
            .firstOrNull;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        children: [
          if (!filters.isEmpty) ...[
            _Chip(
              label: l10n.filterReset,
              icon: Icons.close,
              onTap: () => onChanged(const SearchFilters()),
            ),
            const SizedBox(width: 8),
          ],
          _Chip(
            label: category ?? l10n.filterCategory,
            selected: filters.categorySlug != null,
            onTap: () => _pickCategory(context),
            onClear: filters.categorySlug == null
                ? null
                : () => onChanged(filters.copyWith(clearCategory: true)),
          ),
          const SizedBox(width: 8),
          // Size, shoe size, subject… whatever this category can be narrowed by.
          for (final field
              in attributeFieldsFor(categories, filters.categorySlug).where(
                (f) =>
                    f.filterable &&
                    f.options.isNotEmpty &&
                    (f.type == 'single' || f.type == 'multi'),
              )) ...[
            _Chip(
              label: filters.attrs[field.key] == null
                  ? field.label(locale)
                  : '${field.label(locale)}: ${field.optionLabel(filters.attrs[field.key]!, locale)}',
              selected: filters.attrs[field.key] != null,
              onTap: () => _pickAttr(context, field),
              onClear: filters.attrs[field.key] == null
                  ? null
                  : () => onChanged(
                      filters.copyWith(
                        attrs: Map<String, String>.from(filters.attrs)
                          ..remove(field.key),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          _Chip(
            label: _priceLabel(l10n),
            selected: filters.minCents != null || filters.maxCents != null,
            onTap: () => _pickPrice(context),
            onClear: (filters.minCents == null && filters.maxCents == null)
                ? null
                : () => onChanged(filters.copyWith(clearPrice: true)),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: filters.condition == null
                ? l10n.filterCondition
                : conditionLabel(l10n, filters.condition!) ??
                    filters.condition!,
            selected: filters.condition != null,
            onTap: () => _pickCondition(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: filters.sort == 'recent'
                ? l10n.filterSort
                : _sortLabel(l10n, filters.sort),
            selected: filters.sort != 'recent',
            onTap: () => _pickSort(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: l10n.homeNearMe,
            icon: Icons.my_location,
            selected: filters.nearMe,
            onTap: () => _toggleNearMe(context),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _Chip({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final fg = selected ? tokens.onAccentFill : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, onClear != null ? 8 : 14, 8),
        decoration: BoxDecoration(
          color: selected ? tokens.accentFill : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: fg),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 2),
              // A filter you can see is on should be removable where it is,
              // not only by reopening the sheet that set it.
              Tappable(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentsView extends StatelessWidget {
  final List<String> recents;
  final String prompt;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  const _RecentsView({
    required this.recents,
    required this.prompt,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (recents.isEmpty) {
      return _Message(icon: Icons.search, text: prompt);
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.searchRecent,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                  onPressed: onClear, child: Text(l10n.searchClearRecents)),
            ],
          ),
        ),
        for (final term in recents)
          ListTile(
            leading: Icon(Icons.history, color: scheme.onSurfaceVariant),
            title: Text(term),
            trailing: Icon(Icons.north_west,
                size: 16, color: scheme.onSurfaceVariant),
            onTap: () => onPick(term),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Min/max in whole currency units, returned as `[minCents, maxCents]`.
class _PriceSheet extends StatefulWidget {
  final int? minCents;
  final int? maxCents;

  const _PriceSheet({this.minCents, this.maxCents});

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  /// Both directions go through the currency-aware helpers.
  ///
  /// This sheet used to divide and multiply by 100 flat. The CFA franc has no
  /// minor unit — 145000 XAF *is* 145.000 FCFA — so typing "5000" filtered at
  /// 500.000 FCFA and the chip above then read "500.000 FCFA" back, which made
  /// the filter look like it was working. Same class of bug the write path
  /// already fixed; see toMinorUnits in models.dart.
  static String _display(int? minor) {
    if (minor == null) return '';
    final n = fromMinorUnits(minor);
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  late final TextEditingController _min =
      TextEditingController(text: _display(widget.minCents));
  late final TextEditingController _max =
      TextEditingController(text: _display(widget.maxCents));

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  int? _cents(TextEditingController c) {
    final n = int.tryParse(c.text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    return n == null ? null : toMinorUnits(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, safeBottom(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.filterPrice,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.priceMin,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.priceMax,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, <int?>[null, null]),
                  child: Text(l10n.filterAny),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    var min = _cents(_min);
                    var max = _cents(_max);
                    // A range typed backwards is a typo, not a request for
                    // nothing: swapping it returns what they meant.
                    if (min != null && max != null && min > max) {
                      final t = min;
                      min = max;
                      max = t;
                    }
                    Navigator.pop(context, <int?>[min, max]);
                  },
                  child: Text(l10n.filterApply),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

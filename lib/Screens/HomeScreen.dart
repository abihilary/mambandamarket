import 'dart:async';

import 'package:flutter/material.dart';

// Components
import '../Components/CategoryItem.dart';
import '../Components/ItemCard.dart';
import '../Components/ItemDetailScreen.dart';

// Backend
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../Components/home_board.dart';
import '../api/board_media_cache.dart';
import '../api/board_repository.dart';
import '../Components/category_icons.dart';
import '../Components/category_picker.dart';
import '../theme/app_tokens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Sentinel stored in [_error] for a generic network failure, so the
  /// user-facing message can be localized in build() rather than baked in at
  /// fetch time (which runs from initState, before localizations are ready).
  static const String _networkErrorSentinel = '__network__';

  final _repo = ListingsRepository.instance;
  final _favorites = FavoritesRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  String? _selectedSlug; // null == "For You"
  String _searchQuery = '';
  Timer? _searchDebounce;

  /// Anchor for the gallery's "See all". The rail shows the first eight of
  /// exactly the same list the grid below shows in full, so "all of them" is a
  /// place on this page rather than another screen.
  final GlobalKey _recommendedKey = GlobalKey();

  List<Listing> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The tabs live in an IndexedStack: this screen is built once at launch
    // and then never rebuilt on its own. Without this, a seller published an
    // item and came back to a feed frozen at app start, with their own
    // listing missing from it.
    _repo.revision.addListener(_onCatalogueChanged);
    _loadCategories();
    _loadListings();
    _loadBoard();
    AuthService.instance.me.addListener(_onMeChanged);
  }

  @override
  void dispose() {
    _repo.revision.removeListener(_onCatalogueChanged);
    AuthService.instance.me.removeListener(_onMeChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onMeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // Non-fatal: the feed still works with just "For You".
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _repo.browse(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        categorySlug: _selectedSlug,
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _listings = items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _networkErrorSentinel;
        _isLoading = false;
      });
    }
  }

  /// Debounced so typing doesn't fire a request per keystroke.
  void _onSearchChanged(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _loadListings());
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    setState(() {});
  }

  /// Refresh the board, then let the media cache drop anything it no longer
  /// refers to. Never throws — see BoardRepository.
  Future<void> _loadBoard() async {
    await BoardRepository.instance.load();
    await BoardMediaCache.instance.reconcile(BoardRepository.instance.board.value);
  }

  void _onCatalogueChanged() {
    if (mounted) _loadListings();
  }

  /// The categories the bar offers: top-level groups only.
  ///
  /// Every leaf in the bar would be eighty-eight tiles of horizontal scrolling
  /// to reach "Zu verschenken". Browsing a root sweeps everything filed
  /// underneath it (see migration 0031), so the roots are a complete way in.
  List<Category> get _barCategories =>
      _categories.where((c) => c.isRoot).toList();

  /// A `category` link on the board filters the feed, exactly as tapping the
  /// category bar does.
  ///
  /// Sets the slug directly rather than going through a bar index: a board can
  /// link to a leaf, and leaves are deliberately not in the bar.
  void _onCategorySlug(String slug) {
    if (!_categories.any((c) => c.slug == slug)) return; // since removed
    setState(() => _selectedSlug = slug);
    _loadListings();
  }

  void _onCategoryTapped(int index) {
    final bar = _barCategories;
    // The last chip is "More", not a category: the strip shows the sixteen
    // groups, and everything below them lives in the picker.
    if (index == bar.length + 1) {
      _openCategoryPicker();
      return;
    }
    setState(() {
      // Index 0 is the synthetic "For You" entry.
      _selectedSlug = index == 0 ? null : bar[index - 1].slug;
    });
    _loadListings();
  }

  /// The full tree, reusing the sheet the publish form already uses.
  Future<void> _openCategoryPicker() async {
    if (_categories.isEmpty) return;
    final picked = await showCategoryPicker(
      context,
      categories: _categories,
      selectedSlug: _selectedSlug,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedSlug = picked);
    _loadListings();
  }

  void _openItemDetail(Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          title: listing.title,
          price: listing.displayPrice,
          imageUrl: listing.primaryImageUrl,
          images: listing.imageUrls,
          // Needed for related items, favouriting and messaging the seller.
          listingId: listing.id,
          listing: listing,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Listing listing) async {
    final l10n = context.l10n;
    try {
      await _favorites.toggle(listing.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isUnauthorized
              ? l10n.favoriteSignInRequired
              : l10n.favoriteUpdateFailed),
        ),
      );
    }
  }

  /// "Good morning Hilary" — greeting by local hour, name when we have one.
  ///
  /// The name is appended rather than interpolated into each phrase so the
  /// greeting still reads correctly in the moment before /me resolves, and for
  /// an account that never set a display name.
  String _greeting(BuildContext context, Me? me) {
    final l10n = context.l10n;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.homeGreetingMorning
        : hour < 18
            ? l10n.homeGreetingAfternoon
            : l10n.homeGreetingEvening;
    final name = me?.profile?.displayName?.trim() ?? '';
    final first = name.isEmpty ? '' : name.split(' ').first;
    return first.isEmpty ? '$greeting 👋' : '$greeting $first 👋';
  }

  void _seeAll() {
    final ctx = _recommendedKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  String _selectedLabel(BuildContext context) {
    if (_selectedSlug == null) return context.l10n.forYou;
    return _categories
        .firstWhere(
          (c) => c.slug == _selectedSlug,
      orElse: () => Category(slug: _selectedSlug!, label: _selectedSlug!),
    )
        .displayLabel(Localizations.localeOf(context));
  }

  List<CategoryItem> _categoryItems(BuildContext context) {
    // When a leaf is filtering the feed — reached from a board link — light up
    // the group it belongs to, so the bar is not left showing no selection at
    // all while the header names a category.
    final selected = _selectedSlug;
    final selectedRoot = selected == null
        ? null
        : _categories
            .where((c) => c.slug == selected)
            .map((c) => c.parentSlug ?? c.slug)
            .firstOrNull;

    return [
      CategoryItem(
        label: context.l10n.forYou,
        icon: Icons.thumb_up_alt_outlined,
        isSelected: selected == null,
      ),
      ..._barCategories.map(
        (c) => CategoryItem(
          label: c.displayLabel(Localizations.localeOf(context)),
          icon: categoryIcon(c),
          isSelected: c.slug == selectedRoot,
        ),
      ),
      // Never "selected" — it opens the picker rather than filtering. Hidden
      // until the categories arrive, since the sheet it opens is built from
      // them and would come up empty.
      if (_categories.isNotEmpty)
        CategoryItem(
          label: context.l10n.homeMoreCategories,
          icon: Icons.more_horiz,
          isSelected: false,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _listings.take(8).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadListings(), _favorites.refresh(), _loadBoard()]);
          },
          child: CustomScrollView(
            slivers: [
              // Greeting. The deck opens on the person rather than on the
              // search field, which is what makes the feed read as "yours".
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ValueListenableBuilder<Me?>(
                    valueListenable: AuthService.instance.me,
                    builder: (context, me, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(context, me),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.homeGreetingSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search Bar Row with Notification Icon integrated
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                  child: Row(
                    children: [
                      // Floating Search Bar Field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              _onSearchChanged(val);
                              setState(() {});
                            },
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: context.l10n.homeSearchHint,
                              hintStyle: TextStyle(
                                color: scheme.onSurfaceVariant.withAlpha(180),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: scheme.primary,
                                size: 22,
                              ),
                              // The pin that used to sit here was decoration
                              // dressed as a control: a tappable-looking tile
                              // in a text field, wired to nothing. The real
                              // location control arrives with the distance
                              // work; until then there is nothing to fake.
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 18),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                                horizontal: 16.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The notification bell that sat here was
                      // `onPressed: () {}` — a prominent, brightly filled
                      // button that did nothing at all. There is no
                      // notifications screen to route it to, so it is gone
                      // rather than left as a promise the app cannot keep.
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: CategoryBar(
                  categories: _categoryItems(context),
                  onSelectCategory: _onCategoryTapped,
                ),
              ),

              // Was a hardcoded picsum.photos placeholder — a random stock
              // photo shown to every user since this screen was written. It is
              // now whatever an admin published, and nothing at all when they
              // have published nothing.
              SliverToBoxAdapter(
                child: HomeBoard(onCategory: _onCategorySlug),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off,
                              size: 48, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            _error == _networkErrorSentinel
                                ? context.l10n.connectionError
                                : _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _loadListings,
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_listings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 48, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? context.l10n.nothingFoundFor(_searchQuery)
                                  : context.l10n
                                  .noListingsIn(_selectedLabel(context)),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n
                                    .galleryTitle(_selectedLabel(context)),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: _seeAll,
                              style: TextButton.styleFrom(
                                foregroundColor: context.tokens.accentInk,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(context.l10n.homeSeeAll),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 210,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: gallery.length,
                          itemBuilder: (context, index) {
                            final item = gallery[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: ItemCard(
                                imageUrl: item.primaryImageUrl,
                                title: item.title,
                                price: item.displayPrice,
                                location: item.city,
                                isCompact: true,
                                onTap: () => _openItemDetail(item),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
                        child: Text(
                          context.l10n.recommendedForYou,
                          key: _recommendedKey,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: ValueListenableBuilder<Set<String>>(
                        valueListenable: _favorites.favoriteIds,
                        builder: (context, favIds, _) => SliverGrid(
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final item = _listings[index];
                              return ItemCard(
                                imageUrl: item.primaryImageUrl,
                                title: item.title,
                                price: item.displayPrice,
                                location: item.city,
                                isFavorite: favIds.contains(item.id),
                                onTap: () => _openItemDetail(item),
                                onFavoriteToggle: () => _toggleFavorite(item),
                              );
                            },
                            childCount: _listings.length,
                          ),
                        ),
                      ),
                    ),
                  ],

              // Clears the docked FAB, which overhangs the bar and would
              // otherwise sit on top of the last row of cards.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }
}
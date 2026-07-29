import 'dart:async';

import 'package:flutter/material.dart';

// Components
import '../Components/CategoryItem.dart';
import '../Components/ItemCard.dart';
import '../Components/ItemDetailScreen.dart';
import '../Components/SearchHeader.dart';

// Backend
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';

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

  /// Icon per seeded category slug; anything new falls back to a generic tag.
  static const Map<String, IconData> _categoryIcons = {
    'auto-rad': Icons.directions_car_outlined,
    'elektronik': Icons.devices_outlined,
    'mode': Icons.checkroom_outlined,
    'familie': Icons.child_friendly_outlined,
    'real-estate': Icons.home_outlined,
    'sport': Icons.sports_basketball_outlined,
    'jobs': Icons.work_outline,
    'moebel': Icons.weekend_outlined,
    'haustiere': Icons.pets_outlined,
    'dienstleistungen': Icons.handyman_outlined,
    'buecher-musik': Icons.menu_book_outlined,
    'verschenken': Icons.card_giftcard_outlined,
  };

  final _repo = ListingsRepository.instance;
  final _favorites = FavoritesRepository.instance;

  List<Category> _categories = [];
  String? _selectedSlug; // null == "For You"
  String _searchQuery = '';
  Timer? _searchDebounce;

  List<Listing> _listings = [];
  bool _isLoading = true;
  String? _error;

  /// Search radius shown next to the city. The backend already supports
  /// `near`/`radius`; wiring a real device position is the remaining step, so
  /// this is presentational for now rather than pretending to filter.
  static const int _radiusKm = 25;

  /// The user's own city, once /me has loaded. Falls back to a neutral label
  /// rather than naming a town the user has nothing to do with.
  String _locationLabel(BuildContext context) {
    final city = AuthService.instance.me.value?.profile?.city;
    return (city == null || city.isEmpty)
        ? context.l10n.wholeRegion
        : context.l10n.regionWithRadius(city, _radiusKm);
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadListings();
    // /me may resolve after first paint; refresh the header when it does.
    AuthService.instance.me.addListener(_onMeChanged);
  }

  @override
  void dispose() {
    AuthService.instance.me.removeListener(_onMeChanged);
    _searchDebounce?.cancel();
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

  void _onCategoryTapped(int index) {
    setState(() {
      // Index 0 is the synthetic "For You" entry.
      _selectedSlug = index == 0 ? null : _categories[index - 1].slug;
    });
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

  String _selectedLabel(BuildContext context) {
    if (_selectedSlug == null) return context.l10n.forYou;
    return _categories
        .firstWhere(
          (c) => c.slug == _selectedSlug,
          orElse: () => Category(slug: _selectedSlug!, label: _selectedSlug!),
        )
        .displayLabel;
  }

  List<CategoryItem> _categoryItems(BuildContext context) => [
        CategoryItem(
          label: context.l10n.forYou,
          icon: Icons.thumb_up_alt_outlined,
          isSelected: _selectedSlug == null,
        ),
        ..._categories.map(
          (c) => CategoryItem(
            label: c.displayLabel,
            icon: _categoryIcons[c.slug] ?? Icons.sell_outlined,
            isSelected: c.slug == _selectedSlug,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // The horizontal strip highlights the newest few; the grid shows everything.
    final gallery = _listings.take(8).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadListings(), _favorites.refresh()]);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SearchHeader(
                  locationText: _locationLabel(context),
                  onSearchChanged: _onSearchChanged,
                  onNotificationTap: () {},
                ),
              ),

              SliverToBoxAdapter(
                child: CategoryBar(
                  categories: _categoryItems(context),
                  onSelectCategory: _onCategoryTapped,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      "https://picsum.photos/600/250?random=10",
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
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
                          const Icon(Icons.cloud_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                              _error == _networkErrorSentinel
                                  ? context.l10n.connectionError
                                  : _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
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
                          const Icon(Icons.search_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? context.l10n.nothingFoundFor(_searchQuery)
                                : context.l10n.noListingsIn(_selectedLabel(context)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      context.l10n.galleryTitle(_selectedLabel(context)),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
                    child: Text(context.l10n.recommendedForYou,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

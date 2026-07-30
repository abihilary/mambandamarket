import 'package:flutter/material.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import 'ItemCard.dart';

class ItemDetailScreen extends StatefulWidget {
  final String title;
  final String price;
  final String imageUrl;
  final List<String>? images; // Optional list for multi-image gallery

  /// Backing listing id. Required for anything that touches the server —
  /// related items, favouriting, and starting a conversation — so those
  /// actions stay disabled when the screen is opened without one.
  final String? listingId;

  /// Full record, when the caller already has it. Supplies the description,
  /// location and view count; without it those fall back to placeholders.
  final api.Listing? listing;

  const ItemDetailScreen({
    Key? key,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.images,
    this.listingId,
    this.listing,
  }) : super(key: key);

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  bool _isFavorite = false;

  // List of images (defaults to widget.imageUrl + generated mock samples if empty)
  late List<String> _imageList;

  // "More like this" — same seller first, topped up from the same category.
  List<api.Listing> _relatedItems = [];
  bool _startingChat = false;

  /// Browse returns a summary (no description, single image), so the full
  /// record is fetched on open. Until it lands, whatever the caller passed is
  /// shown, which keeps the screen populated instead of flashing empty.
  api.Listing? _full;
  api.Listing? get _listing => _full ?? widget.listing;

  Future<void> _loadDetail() async {
    final id = widget.listingId;
    if (id == null) return;
    try {
      final full = await ListingsRepository.instance.detail(id);
      if (!mounted) return;
      setState(() {
        _full = full;
        _isFavorite = full.isFavorited;
        if (full.imageUrls.isNotEmpty) _imageList = full.imageUrls;
      });
    } catch (_) {
      // Keep the summary we already have.
    }
  }

  /// Relative age of the listing, e.g. "Vor 3 Stunden".
  String get _postedLabel {
    final at = _listing?.createdAt;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return context.l10n.detailPostedMinutes(d.inMinutes);
    if (d.inHours < 24) return context.l10n.detailPostedHours(d.inHours);
    return context.l10n.detailPostedDays(d.inDays);
  }

  Future<void> _loadRelated() async {
    final id = widget.listingId;
    if (id == null) return;
    try {
      final items = await ListingsRepository.instance.related(id);
      if (mounted) setState(() => _relatedItems = items);
    } catch (_) {
      // Non-fatal: the row just stays empty.
    }
  }

  Future<void> _toggleFavorite() async {
    final id = widget.listingId;
    if (id == null) return;
    final l10n = context.l10n;
    try {
      await FavoritesRepository.instance.toggle(id);
      if (mounted) {
        setState(() =>
            _isFavorite = FavoritesRepository.instance.isFavorite(id));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            e.isUnauthorized ? l10n.detailSignInToSave : e.message)),
      );
    }
  }

  /// Opens (or reuses) the thread for this listing, then shows the room.
  Future<void> _contactSeller() async {
    final id = widget.listingId;
    if (id == null) return;
    final l10n = context.l10n;
    if (AuthService.instance.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.detailSignInToMessage)),
      );
      return;
    }
    setState(() => _startingChat = true);
    try {
      final conversation = await ChatRepository.instance.start(id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(conversation: conversation),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // The API rejects messaging yourself with a specific code.
          content: Text(e.code == 'own_listing'
              ? l10n.detailOwnListing
              : e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _isFavorite = widget.listingId != null &&
        FavoritesRepository.instance.isFavorite(widget.listingId!);
    _loadDetail();
    _loadRelated();

    // Populate gallery slider list
    _imageList = widget.images ?? [
      widget.imageUrl,
      "https://picsum.photos/600/600?random=31",
      "https://picsum.photos/600/600?random=32",
      "https://picsum.photos/600/600?random=33",
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Image Gallery Header Slider with PageView
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.indigo,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                    size: 20,
                  ),
                  // Persists through the API; local state follows the server.
                  onPressed: widget.listingId == null ? null : _toggleFavorite,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Horizontal PageView for Multiple Images
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _imageList.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _imageList[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      );
                    },
                  ),

                  // Image Counter Indicator (e.g. "1/4")
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_currentImageIndex + 1}/${_imageList.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Item Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Tag
                  Text(
                    _listing?.city ?? '—',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Price Bar
                  Row(
                    children: [
                      Text(
                        widget.price,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _listing?.condition ?? context.l10n.detailConditionFallback,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Meta details
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_postedLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(context.l10n.detailViews(_listing?.viewCount ?? 0),
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 32),

                  // Description
                  Text(context.l10n.detailDetails, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    (_listing?.description?.isNotEmpty ?? false)
                        ? _listing!.description!
                        : context.l10n.detailNoDescription,
                    style: const TextStyle(height: 1.4, color: Colors.black87, fontSize: 14),
                  ),
                  const Divider(height: 40),

                  // 3. Related / Other Shop Items Section Header
                  Text(
                    context.l10n.detailRelated,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 4. Grid of Other Related Shop Items
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = _relatedItems[index];
                  return ItemCard(
                    imageUrl: item.primaryImageUrl,
                    title: item.title,
                    price: item.displayPrice,
                    onTap: () {
                      Navigator.push(
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
                    },
                  );
                },
                childCount: _relatedItems.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),

      // Floating Bottom Message Action Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 2,
            ),
            onPressed:
                (widget.listingId == null || _startingChat) ? null : _contactSeller,
            icon: _startingChat
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.chat_bubble_outline),
            label: Text(
              context.l10n.detailMessageSeller,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
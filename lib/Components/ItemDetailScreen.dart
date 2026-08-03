import 'package:flutter/material.dart';

import '../Screens/CheckoutScreen.dart';
import '../Service/ChatRoomScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'ItemCard.dart';
import 'report_sheet.dart';

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
  bool _dontShowSafetyNoticeAgain = false;

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

  /// Only a verified company's listing can be bought and escrowed in-app;
  /// everything else is a classified ad settled over chat.
  bool get _isBuyable => _listing?.isBuyable ?? false;

  /// Opens checkout. The listing is passed whole so the checkout screen can
  /// price and picture the item without a second fetch.
  void _buyNow() {
    final listing = _listing;
    if (listing == null || !listing.isBuyable) return;
    if (AuthService.instance.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.checkoutSignInRequired)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(listing: listing)),
    );
  }

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

  /// Prompt the user with a payment & delivery safety warning before proceeding to chat.
  void _onChatPressed() {
    if (_dontShowSafetyNoticeAgain) {
      _contactSeller();
    } else {
      _showSafetyWarningDialog();
    }
  }

  void _showSafetyWarningDialog() {
    bool dontShowAgainLocal = _dontShowSafetyNoticeAgain;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Safety & Payment Notice",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Please keep your transaction safe by adhering to the following rules:",
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSafetyBullet(
                    ctx,
                    icon: Icons.storefront_outlined,
                    title: "On-Site Transaction",
                    description: "Payment and item inspection should be completed on-site during delivery.",
                  ),
                  const SizedBox(height: 10),
                  _buildSafetyBullet(
                    ctx,
                    icon: Icons.location_on_outlined,
                    title: "Meet in Secure Locations",
                    description: "Always arrange meetings in well-lit, public, and secure locations.",
                  ),
                  const SizedBox(height: 10),
                  _buildSafetyBullet(
                    ctx,
                    icon: Icons.report_problem_outlined,
                    title: "Platform Disclaimer",
                    description: "The platform is not liable for advance payments or agreements made independently between parties.",
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: dontShowAgainLocal,
                          activeColor: cs.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              dontShowAgainLocal = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            dontShowAgainLocal = !dontShowAgainLocal;
                          });
                        },
                        child: Text(
                          "Don't show this again",
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [

                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
                SizedBox(height: 8,),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _dontShowSafetyNoticeAgain = dontShowAgainLocal;
                    });
                    Navigator.pop(ctx);
                    _contactSeller();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Proceed to Chat",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSafetyBullet(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String description,
      }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          backgroundColor: AppColors.danger,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Image Gallery Header Slider with PageView
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppColors.danger : Colors.white,
                    size: 20,
                  ),
                  onPressed: widget.listingId == null ? null : _toggleFavorite,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.flag_outlined,
                      color: Colors.white, size: 20),
                  onSelected: (value) {
                    final l10n = context.l10n;
                    final listing = _listing;
                    if (value == 'listing' && widget.listingId != null) {
                      showReportSheet(context,
                          targetType: 'listing',
                          targetId: widget.listingId!,
                          title: l10n.reportListing);
                    } else if (value == 'seller' && listing != null) {
                      showReportSheet(context,
                          targetType: 'user',
                          targetId: listing.sellerId,
                          title: l10n.reportSeller);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = context.l10n;
                    return [
                      PopupMenuItem(
                          value: 'listing',
                          child: Text(l10n.reportListing)),
                      PopupMenuItem(
                          value: 'seller', child: Text(l10n.reportSeller)),
                    ];
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
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
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.broken_image,
                              size: 50, color: scheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
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
                  Text(
                    _listing?.city ?? '—',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        widget.price,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _listing?.condition ?? context.l10n.detailConditionFallback,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (_isBuyable) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.detailVerifiedCompany,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 32),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_postedLabel,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 16),
                      Icon(Icons.remove_red_eye_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(context.l10n.detailViews(_listing?.viewCount ?? 0),
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(context.l10n.detailDetails, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    (_listing?.description?.isNotEmpty ?? false)
                        ? _listing!.description!
                        : context.l10n.detailNoDescription,
                    style: TextStyle(
                        height: 1.4, color: scheme.onSurface, fontSize: 14),
                  ),
                  const Divider(height: 40),
                  Text(
                    context.l10n.detailRelated,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 3. Grid of Other Related Shop Items
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

      // Floating Bottom Action Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isBuyable) ...[
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.detailBuyerProtected,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (_isBuyable) ...[
                    Expanded(flex: 3, child: _buyButton()),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _chatButton(primary: false)),
                  ] else
                    Expanded(child: _chatButton(primary: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buyButton() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      minimumSize: const Size(0, 50),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 2,
    ),
    onPressed: _buyNow,
    icon: const Icon(Icons.shopping_bag_outlined),
    label: Text(
      context.l10n.detailBuyNow,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );

  /// [primary] fills the button when it's the only action on the bar, and
  /// outlines it when it sits next to "Buy now".
  Widget _chatButton({required bool primary}) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.listingId == null || _startingChat;
    final icon = _startingChat
        ? SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: primary ? scheme.onPrimary : scheme.primary,
      ),
    )
        : const Icon(Icons.chat_bubble_outline);
    final label = Text(
      context.l10n.detailMessageSeller,
      style: TextStyle(
          fontSize: primary ? 16 : 14, fontWeight: FontWeight.bold),
    );

    if (!primary) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.primary),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onPressed: disabled ? null : _onChatPressed,
        icon: icon,
        label: label,
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 2,
      ),
      onPressed: disabled ? null : _onChatPressed,
      icon: icon,
      label: label,
    );
  }
}
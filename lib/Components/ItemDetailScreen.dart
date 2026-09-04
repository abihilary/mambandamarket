import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../Screens/CheckoutScreen.dart';
import '../Screens/PublicProfileScreen.dart';
import '../Service/ChatRoomScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../api/share_links.dart';
import '../l10n/l10n.dart';
import 'glass_surface.dart';
import '../theme/app_theme.dart';
import 'ItemCard.dart';
import 'VerifiedBadge.dart';
import 'report_sheet.dart';

class ItemDetailScreen extends StatefulWidget {
  final String title;
  final String price;
  final String imageUrl;
  final List<String>? images;

  /// Listing ID used for:
  /// - loading the complete listing
  /// - favourites
  /// - related listings
  /// - starting a conversation
  /// - sharing the listing
  final String? listingId;

  /// Listing supplied by HomeScreen.
  ///
  /// HomeScreen already has a Listing object from browse(), so we can
  /// immediately display useful information while the detail request runs.
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
  late final PageController _pageController;

  int _currentImageIndex = 0;

  bool _isFavorite = false;
  bool _dontShowSafetyNoticeAgain = false;
  bool _startingChat = false;
  bool _loadingDetail = false;

  /// Prevents multiple share requests from being triggered by repeated taps.
  bool _isSharing = false;

  late List<String> _imageList;

  List<api.Listing> _relatedItems = [];

  /// Full listing fetched from the API.
  ///
  /// We initially use widget.listing, then replace it with the full record
  /// once detail() completes.
  api.Listing? _full;

  api.Listing? get _listing => _full ?? widget.listing;

  /// Only listings that the backend marks as buyable can use checkout.
  bool get _isBuyable => _listing?.isBuyable ?? false;

  // ===========================================================================
  // SHARE CONFIGURATION
  // ===========================================================================

  /// -------------------------------------------------------------------------
  /// PUBLIC WEB URL of the marketplace.
  /// -------------------------------------------------------------------------
  ///
  /// This pointed at mambandamarket.com/listing, which nothing serves — the
  /// sheet opened, the message sent, and whoever received it tapped a link
  /// that went nowhere. It now points at the subdomain the app actually ships
  /// on, at the route that renders the listing (site repo, `api/l.js` behind
  /// the `/l/:id` rewrite).
  ///
  /// The shape lives in ShareLinks so this end and the incoming end cannot
  /// drift apart: the same class parses a link arriving back into the app.

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _initializeImages();

    if (widget.listingId != null) {
      _isFavorite = FavoritesRepository.instance.isFavorite(
        widget.listingId!,
      );
    }

    _loadDetail();
    _loadRelated();
  }

  // ===========================================================================
  // IMAGE INITIALIZATION
  // ===========================================================================

  /// Uses the images supplied by HomeScreen/listing.
  void _initializeImages() {
    final suppliedImages = widget.images
        ?.where((url) => url.trim().isNotEmpty)
        .toList();

    if (suppliedImages != null && suppliedImages.isNotEmpty) {
      _imageList = List<String>.from(suppliedImages);
      return;
    }

    if (widget.imageUrl.trim().isNotEmpty) {
      _imageList = [widget.imageUrl];
      return;
    }

    _imageList = [];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // SHARE
  // ===========================================================================

  /// Creates the public URL for this listing.
  String? _buildListingShareUrl() {
    final id = widget.listingId?.trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return ShareLinks.listing(id).toString();
  }

  /// Builds the content that is shared through the native share sheet.
  String _buildShareText() {
    final listing = _listing;

    final title = (
      listing?.title ??
      widget.title
    ).trim();

    final price = (
      listing?.displayPrice ??
      widget.price
    ).trim();

    final condition = (
      listing?.condition ??
      ''
    ).trim();

    final city = (
      listing?.city ??
      ''
    ).trim();

    final buffer = StringBuffer();

    buffer.writeln(title);

    if (price.isNotEmpty) {
      buffer.writeln('Price: $price');
    }

    if (condition.isNotEmpty) {
      buffer.writeln('Condition: $condition');
    }

    if (city.isNotEmpty) {
      buffer.writeln('Location: $city');
    }

    final shareUrl = _buildListingShareUrl();

    if (shareUrl != null) {
      buffer.writeln();
      buffer.writeln('View this listing on Mambanda Market:');
      buffer.writeln(shareUrl);
    } else {
      buffer.writeln();
      buffer.writeln('Shared from Mambanda Market.');

      if (widget.listingId != null &&
          widget.listingId!.trim().isNotEmpty) {
        buffer.writeln(
          'Listing ID: ${widget.listingId!.trim()}',
        );
      }
    }

    return buffer.toString().trim();
  }

  /// Opens the native platform share sheet.
  Future<void> _shareListing(BuildContext buttonContext) async {
    if (_isSharing) {
      return;
    }

    final listing = _listing;

    final title = (
      listing?.title ??
      widget.title
    ).trim();

    if (title.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This listing cannot be shared right now.',
          ),
        ),
      );

      return;
    }

    final text = _buildShareText();

    final renderObject =
        buttonContext.findRenderObject();

    Rect? sharePositionOrigin;

    if (renderObject is RenderBox) {
      sharePositionOrigin =
          renderObject.localToGlobal(
                Offset.zero,
              ) &
              renderObject.size;
    }

    if (!mounted) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // share_plus 13 replaced the static Share.share with an instance and a
      // params object. The pin moved because 10.1.4 does not compile against
      // this project's Kotlin/AGP — its Android source references a
      // ShareSuccessManager that no longer resolves — so the call site moves
      // with it. Behaviour is unchanged: same text, same subject, same origin
      // rect, same handling of the result.
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Check out this listing: $title',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (!mounted) return;

      if (result.status == ShareResultStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing is not available on this device.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to share this listing. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  // ===========================================================================
  // API
  // ===========================================================================

  Future<void> _loadDetail() async {
    final id = widget.listingId;

    if (id == null || id.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingDetail = true;
      });
    }

    try {
      final full =
          await ListingsRepository.instance.detail(id);

      if (!mounted) return;

      final serverImages = full.imageUrls
          .where((url) => url.trim().isNotEmpty)
          .toList();

      setState(() {
        _full = full;
        _isFavorite = full.isFavorited;

        if (serverImages.isNotEmpty) {
          _imageList = serverImages;
        }

        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingDetail = false;
      });
    }
  }

  Future<void> _loadRelated() async {
    final id = widget.listingId;

    if (id == null || id.isEmpty) {
      return;
    }

    try {
      final items =
          await ListingsRepository.instance.related(id);

      if (!mounted) return;

      setState(() {
        _relatedItems = items;
      });
    } catch (_) {
      // Related listings are non-critical.
    }
  }

  // ===========================================================================
  // FAVORITES
  // ===========================================================================

  Future<void> _toggleFavorite() async {
    final id = widget.listingId;

    if (id == null || id.isEmpty) {
      return;
    }

    final l10n = context.l10n;

    try {
      await FavoritesRepository.instance.toggle(id);

      if (!mounted) return;

      setState(() {
        _isFavorite =
            FavoritesRepository.instance.isFavorite(id);
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isUnauthorized
                ? l10n.detailSignInToSave
                : e.message,
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // CHECKOUT
  // ===========================================================================

  void _buyNow() {
    final listing = _listing;

    if (listing == null || !listing.isBuyable) {
      return;
    }

    if (AuthService.instance.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.checkoutSignInRequired,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          listing: listing,
        ),
      ),
    );
  }

  // ===========================================================================
  // CHAT
  // ===========================================================================

  void _onChatPressed() {
    if (_dontShowSafetyNoticeAgain) {
      _contactSeller();
      return;
    }

    _showSafetyWarningDialog();
  }

  void _showSafetyWarningDialog() {
    bool dontShowAgainLocal =
        _dontShowSafetyNoticeAgain;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final scheme =
            Theme.of(dialogContext).colorScheme;

        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                10,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              title: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n
                          .safetyNoticeTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  Text(
                    context.l10n
                        .safetyNoticeIntro,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSafetyBullet(
                    context,
                    icon:
                        Icons.storefront_outlined,
                    title: context.l10n
                        .safetyOnSiteTitle,
                    description: context.l10n
                        .safetyOnSiteBody,
                  ),

                  const SizedBox(height: 12),

                  _buildSafetyBullet(
                    context,
                    icon:
                        Icons.location_on_outlined,
                    title: context.l10n
                        .safetySecureLocationTitle,
                    description: context.l10n
                        .safetySecureLocationBody,
                  ),

                  const SizedBox(height: 12),

                  _buildSafetyBullet(
                    context,
                    icon:
                        Icons.report_problem_outlined,
                    title: context.l10n
                        .safetyDisclaimerTitle,
                    description: context.l10n
                        .safetyDisclaimerBody,
                  ),

                  const SizedBox(height: 14),

                  const Divider(),

                  const SizedBox(height: 6),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value:
                              dontShowAgainLocal,
                          activeColor:
                              scheme.primary,
                          onChanged: (value) {
                            setDialogState(() {
                              dontShowAgainLocal =
                                  value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              dontShowAgainLocal =
                                  !dontShowAgainLocal;
                            });
                          },
                          child: Text(
                            context.l10n
                                .safetyDontShowAgain,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style:
                      OutlinedButton.styleFrom(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                  child: Text(
                    context.l10n.safetyCancel,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _dontShowSafetyNoticeAgain =
                          dontShowAgainLocal;
                    });

                    Navigator.pop(dialogContext);

                    _contactSeller();
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        scheme.primary,
                    foregroundColor:
                        scheme.onPrimary,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                  child: Text(
                    context.l10n
                        .safetyProceedToChat,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
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
    final scheme =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _contactSeller() async {
    final id = widget.listingId;

    if (id == null || id.isEmpty) {
      return;
    }

    final l10n = context.l10n;

    if (AuthService.instance.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.detailSignInToMessage,
          ),
        ),
      );
      return;
    }

    if (_startingChat) {
      return;
    }

    setState(() {
      _startingChat = true;
    });

    try {
      final conversation =
          await ChatRepository.instance.start(id);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversation: conversation,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'own_listing'
                ? l10n.detailOwnListing
                : e.message,
          ),
          backgroundColor:
              AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _startingChat = false;
        });
      }
    }
  }

  // ===========================================================================
  // IMAGE GALLERY
  // ===========================================================================

  Widget _buildGallery(
    BuildContext context,
    ColorScheme scheme,
  ) {
    if (_imageList.isEmpty) {
      return Container(
        color:
            scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 50,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _imageList.length,
          onPageChanged: (index) {
            if (!mounted) return;

            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Image.network(
              _imageList[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 50,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Gradient overlay for better legibility of indicators
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 90,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Page indicator (Number)
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${_imageList.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Dot indicators
        if (_imageList.length > 1)
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: List.generate(
                _imageList.length,
                (index) {
                  final selected = index == _currentImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 5),
                    height: 6,
                    width: selected ? 18 : 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // RELATED
  // ===========================================================================

  Widget _buildRelatedSection() {
    if (_relatedItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Text(
            context.l10n.detailRelated,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              location: item.city,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
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
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listing = _listing;

    final title = listing?.title ?? widget.title;
    final price = listing?.displayPrice ?? widget.price;
    final condition = listing?.condition ?? context.l10n.detailConditionFallback;
    final city = listing?.city ?? '—';
    final description = (listing?.description?.trim().isNotEmpty ?? false)
        ? listing!.description!
        : context.l10n.detailNoDescription;

    return Scaffold(
      // So the page passes under the action bar and there is something for it
      // to blur. The sliver at the end of the list carries the clearance.
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            elevation: 0,
            backgroundColor: scheme.surface,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // Favorite
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? AppColors.danger : Colors.white,
                      size: 20,
                    ),
                    onPressed: widget.listingId == null ? null : _toggleFavorite,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Share
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Builder(builder: (shareButtonContext) {
                  return CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    child: IconButton(
                      onPressed: _isSharing ? null : () => _shareListing(shareButtonContext),
                      icon: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share, color: Colors.white, size: 20),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),

              // Report
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
                    onSelected: (value) {
                      final l10n = context.l10n;
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
                        PopupMenuItem(value: 'listing', child: Text(l10n.reportListing)),
                        PopupMenuItem(value: 'seller', child: Text(l10n.reportSeller)),
                      ];
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _buildGallery(context, scheme),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city != '—' && city.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 17, color: scheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          condition,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_isBuyable) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 16, color: AppColors.success),
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
                    ),
                  ],
                  const Divider(height: 40),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _postedLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Icon(Icons.remove_red_eye_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.detailViews(listing?.viewCount ?? 0),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  if (listing != null && listing.sellerId.isNotEmpty) ...[
                    _SellerRow(listing: listing),
                    const Divider(height: 40),
                  ],
                  Text(context.l10n.detailDetails,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(height: 1.5, color: scheme.onSurface, fontSize: 14),
                  ),
                  const Divider(height: 56),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.detailRelated,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_relatedItems.isNotEmpty)
                        Text(
                          '${_relatedItems.length}',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: scheme.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _buildRelatedSection(),
          // Clearance for the action bar the content now runs beneath. Sized
          // for the tallest version of that bar — buyer-protection line, buy
          // button and message button — so the last row of related items is
          // never left half-covered by it.
          const SliverToBoxAdapter(child: SizedBox(height: 165)),
        ],
      ),
      bottomNavigationBar: GlassSurface(
        // The drop shadow that used to separate this bar from the page is gone:
        // a translucent surface is already legible as one, and a shadow above a
        // blur reads as a smudge.
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isBuyable && (_listing?.companyEscrow ?? true)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, size: 15, color: AppColors.success),
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
      ),
    );
  }

  String get _postedLabel {
    final createdAt = _listing?.createdAt;
    if (createdAt == null) return '';
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 60) return context.l10n.detailPostedMinutes(difference.inMinutes);
    if (difference.inHours < 24) return context.l10n.detailPostedHours(difference.inHours);
    return context.l10n.detailPostedDays(difference.inDays);
  }

  Widget _buyButton() {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 2,
      ),
      onPressed: _buyNow,
      icon: const Icon(Icons.shopping_bag_outlined),
      label: Text(
        context.l10n.detailBuyNow,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _chatButton({required bool primary}) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.listingId == null || _startingChat;
    final Widget icon = _startingChat
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
      style: TextStyle(fontSize: primary ? 15 : 13, fontWeight: FontWeight.bold),
    );

    if (!primary) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
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

class _SellerRow extends StatelessWidget {
  final api.Listing listing;
  const _SellerRow({required this.listing});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final name = (listing.sellerLabel?.trim().isNotEmpty ?? false)
        ? listing.sellerLabel!
        : l10n.profileFallbackName;
    final image = listing.sellerImageUrl;
    final hasImage = image != null && image.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(
              userId: listing.sellerId,
              initialName: listing.sellerLabel,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              backgroundImage: hasImage ? NetworkImage(image!) : null,
              child: hasImage
                  ? null
                  : Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17, color: scheme.primary),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.detailSoldBy,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (listing.sellerVerified) ...[
                        const SizedBox(width: 5),
                        const VerifiedBadge(dense: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.profileViewSeller,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.primary)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 19, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

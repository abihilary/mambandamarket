import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../Screens/CheckoutScreen.dart';
import '../Screens/PublicProfileScreen.dart';
import '../Screens/SearchScreen.dart';
import '../Screens/ShippingRequestScreen.dart';
import '../Service/ChatRoomScreen.dart';
import '../api/api_client.dart';
import '../api/listing_attributes.dart';
import '../api/listing_guide.dart';
import '../api/listing_presentation.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../api/share_links.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import 'glass_surface.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'ItemCard.dart';
import 'listing_details.dart';
import 'report_sheet.dart';
import 'require_account.dart';
import 'share_menu.dart';
import '../theme/breakpoints.dart';
import 'web_share_flow.dart';

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

  /// What pressed the share button last. A browser cannot be asked whether it
  /// has a touch screen, but the tap itself says whether it was a finger.
  PointerDeviceKind? _sharePointer;

  late List<String> _imageList;

  List<api.Listing> _relatedItems = [];

  /// Full listing fetched from the API.
  ///
  /// We initially use widget.listing, then replace it with the full record
  /// once detail() completes.
  api.Listing? _full;

  api.Listing? get _listing => _full ?? widget.listing;

  /// For the listing's details: the category templates that name them.
  List<api.Category> _categories = const [];

  Future<void> _loadCategories() async {
    try {
      final c = await ListingsRepository.instance.cachedCategories();
      if (mounted) setState(() => _categories = c);
    } catch (_) {
      // Without them the details are simply not listed; the description is.
    }
  }

  /// The listing's category template, leaf fields first.
  List<AttrField> get _fields =>
      api.attributeFieldsFor(_categories, _listing?.categorySlug);

  /// How the category wants it shown: price label, buyer tips, whether
  /// condition, warranty and delivery mean anything, the button's wording.
  ListingGuide get _guide => api.guideFor(_categories, _listing?.categorySlug);

  api.Category? get _category {
    final slug = _listing?.categorySlug;
    for (final c in _categories) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  /// Everything the details block shows, worked out once per build.
  ListingDetails _detailsOf(BuildContext context) {
    final listing = _listing;
    if (listing == null) return ListingDetails.empty;
    return ListingDetails.of(listing, _fields, _guide, context.l10n,
        Localizations.localeOf(context));
  }

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
    _loadCategories();
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

  /// The web build: see shareOnWeb. The link goes in the share's link field
  /// and is what gets copied where there is no share sheet.
  Future<void> _shareOnWeb(String title, String link) {
    return shareOnWeb(context, title: title, url: link, copyText: link);
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

    // Just the link. It used to be a block of text — title, price,
    // condition, place, then the link — which WhatsApp coped with, but pasted
    // into a browser's address bar it became a search and never opened the
    // listing. WhatsApp, Messenger and SMS build their own card (photo, title
    // and price) from the link page's preview tags, so the text added nothing
    // there either. The title still travels as the share's subject.
    final link = _buildListingShareUrl() ?? title;

    if (kIsWeb) {
      // A desktop gets our own menu, "Copy link" first. A phone browser keeps
      // its share sheet, sent the bare link exactly as the app does.
      final touch = _sharePointer == PointerDeviceKind.touch ||
          _sharePointer == PointerDeviceKind.stylus;
      if (context.isWideLayout || !touch) {
        return showShareMenu(
          context,
          anchor: buttonContext,
          title: title,
          priceText: listing?.displayPrice ?? widget.price,
          link: link,
        );
      }
      return _shareOnWeb(title, link);
    }

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
      // share_plus 13: an instance and a params object (10.1.4 does not
      // compile against this project's Kotlin/AGP). `title` names the
      // Android chooser; `subject` fills an email's subject line.
      final result = await SharePlus.instance.share(
        ShareParams(
          text: link,
          subject: title,
          title: title,
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

    if (!await requireAccount(context, l10n.detailSignInToSave,
        returnToListing: id)) {
      return;
    }
    if (!mounted) return;

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

  Future<void> _buyNow() async {
    final listing = _listing;

    if (listing == null || !listing.isBuyable) {
      return;
    }

    if (!await requireAccount(context, context.l10n.checkoutSignInRequired,
        returnToListing: listing.id)) {
      return;
    }
    if (!mounted) return;

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

  Future<void> _onChatPressed() async {
    // Account first: a visitor should not read the safety rules for a chat
    // they then find they cannot open.
    final id = widget.listingId;
    if (!await requireAccount(context, context.l10n.detailSignInToMessage,
        returnToListing: id)) {
      return;
    }
    if (!mounted) return;
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
              // Scrolls when the screen is short — a phone on its side, a
              // small browser window. Without it the rules overflowed on top
              // of the Cancel button, and Cancel could not be pressed.
              scrollable: true,
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

    if (!await requireAccount(context, l10n.detailSignInToMessage,
        returnToListing: id)) {
      return;
    }
    if (!mounted) return;

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

  /// [indicatorLift] raises the dots and the counter clear of whatever sits
  /// on the photo's bottom edge — the key-facts card's top on a phone.
  Widget _buildGallery(
    BuildContext context,
    ColorScheme scheme, {
    BoxFit fit = BoxFit.cover,
    double indicatorLift = 0,
  }) {
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
            return Image(
              image: CachedNetworkImageProvider(_imageList[index]),
              fit: fit,
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
          bottom: 14 + indicatorLift,
          right: 14 + indicatorLift,
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
            bottom: 16 + indicatorLift,
            left: 16 + indicatorLift,
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

  /// The key-facts card: where, what, how much, the facts a buyer decides on.
  /// On a phone it hangs from the gallery ([attachedTop]); on a desktop it
  /// heads the sticky column and carries the buttons ([actions]).
  Widget _keyFactsCard(
    BuildContext context, {
    Widget? actions,
    bool attachedTop = false,
  }) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final listing = _listing;
    final guide = _guide;
    final category = _category;
    final city = listing?.city?.trim() ?? '';
    final views = listing?.viewCount ?? 0;
    return KeyFactsCard(
      attachedTop: attachedTop,
      title: listing?.title ?? widget.title,
      // Until the listing arrives, the price the feed already showed.
      price: listing == null
          ? (main: widget.price, tail: null, negotiableChip: false)
          : priceLine(listing, guide, l10n),
      priceLabel: guide.priceLabel(locale),
      city: city,
      onCityTap: city.isEmpty ? null : () => _openSearch(query: city),
      facts: listing == null
          ? const []
          : keyFacts(listing, _fields, guide, l10n, locale),
      onDeliveryTap: _showsShipping ? _shipThis : null,
      categoryLabel: category?.displayLabel(locale),
      onCategoryTap: category == null
          ? null
          : () => _openSearch(categorySlug: category.slug),
      posted: _postedLabel,
      // Below ten the count is mostly link-preview crawlers, and says nothing.
      views: views >= 10 ? l10n.detailViews(views) : null,
      actions: actions,
    );
  }

  /// "Achat protégé", directly under the key facts — only where it is true:
  /// a buyable listing whose company sells through escrow.
  List<Widget> _escrowBand(BuildContext context) {
    if (!_isBuyable || !(_listing?.companyEscrow ?? true)) return const [];
    return [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.detailBuyerProtected,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Details, description, [seller] when given, and the buyer tips — the
  /// long part of the page, in that order. Under the key facts on a phone;
  /// under the gallery on a desktop, where the table may run in two columns
  /// and the seller sits in the side column instead.
  List<Widget> _bodySections(
    BuildContext context,
    ListingDetails details, {
    int columns = 1,
    int descriptionLines = 5,
    Widget? seller,
  }) {
    final listing = _listing;
    final description = listing?.description?.trim() ?? '';
    // An empty description is only worth a line when the details are thin,
    // and never while the full listing is still on its way.
    final showDescription = description.isNotEmpty ||
        (!_loadingDetail && listing != null && details.rows.length < 4);
    final tips = listing == null
        ? const <String>[]
        : BuyerTipsCard.tipsFor(
            listing,
            _guide,
            context.l10n,
            Localizations.localeOf(context),
            protected: _isBuyable && listing.companyEscrow,
          );
    return [
      if (!details.isEmpty) ...[
        const SizedBox(height: 24),
        DetailsTable(details: details, columns: columns),
      ],
      if (showDescription) ...[
        const SizedBox(height: 24),
        CollapsibleDescription(
          text: description,
          maxLines: descriptionLines,
        ),
      ],
      if (seller != null) ...[
        const SizedBox(height: 24),
        seller,
      ],
      if (tips.isNotEmpty) ...[
        SizedBox(height: seller != null ? 16 : 24),
        BuyerTipsCard(tips: tips),
      ],
    ];
  }

  Widget? _sellerCard() {
    final listing = _listing;
    if (listing == null || listing.sellerId.isEmpty) return null;
    return SellerCard(listing: listing, onTap: () => _openSeller(listing));
  }

  void _openSeller(api.Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: listing.sellerId,
          initialName: listing.sellerLabel,
        ),
      ),
    );
  }

  /// Search for the place or the category, from the key-facts card.
  void _openSearch({String? query, String? categorySlug}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialQuery: query,
          initialCategorySlug: categorySlug,
        ),
      ),
    );
  }

  Widget _relatedHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  // ===========================================================================
  // RELATED
  // ===========================================================================

  Widget _buildRelatedSection({
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    if (_relatedItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: padding.copyWith(bottom: 20),
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
      padding: padding,
      // Columns from the width, as on Home: a fixed two made each card half
      // a desktop window wide.
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: ItemCard.gridDelegate(
            constraints.crossAxisExtent,
            MediaQuery.textScalerOf(context),
            maxTileWidth: 220,
            spacing: 12,
            runSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _relatedItems[index];
              final card = cardText(context, item, _categories);
              return ItemCard(
                imageUrl: item.primaryImageUrl,
                title: item.title,
                price: card.price,
                priceTail: card.priceTail,
                specLine: card.specLine,
                badge: card.badge,
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
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (context.isWideLayout) return _buildWide(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
            actions: _headerActions(context),
            // The key-facts card overlaps the photo by its top 16px. That
            // piece is drawn here, in the bar, because a pinned bar paints
            // over the slivers after it: a card shifted up from below would
            // disappear under the picture.
            flexibleSpace: Builder(builder: (context) {
              final bar = context
                  .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
              final span = bar == null ? 0.0 : bar.maxExtent - bar.minExtent;
              final open = bar == null || span <= 0
                  ? 1.0
                  : ((bar.currentExtent - bar.minExtent) / span).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background:
                        _buildGallery(context, scheme, indicatorLift: 16),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    height: 16,
                    // Gone by the time the card reaches the toolbar and
                    // starts to slide beneath it.
                    child: KeyFactsCap(opacity: (open / 0.2).clamp(0.0, 1.0)),
                  ),
                ],
              );
            }),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _keyFactsCard(context, attachedTop: true),
                  ..._escrowBand(context),
                  ..._bodySections(context, _detailsOf(context),
                      seller: _sellerCard()),
                  const Divider(height: 56),
                  _relatedHeader(context),
                ],
              ),
            ),
          ),
          _buildRelatedSection(),
          // Clearance for the action bar the content now runs beneath, so the
          // last row of related items is never left half-covered by it.
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 96),
          ),
        ],
      ),
      bottomNavigationBar: GlassSurface(
        // The drop shadow that used to separate this bar from the page is gone:
        // a translucent surface is already legible as one, and a shadow above a
        // blur reads as a smudge.
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _buildActions(context),
          ),
        ),
      ),
    );
  }

  /// Buy, message and ship. The buyer-protection line that sat above them is
  /// now the band under the key facts, said once.
  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        if (_isBuyable) ...[
          Expanded(flex: 3, child: _buyButton()),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _chatButton(primary: false)),
        ] else
          Expanded(child: _chatButton(primary: true)),
        // The way in sits with the other actions rather than
        // somewhere they would have to go looking for. Icon-only and
        // last, so it never competes with buying or messaging.
        if (_showsShipping) ...[
          const SizedBox(width: 10),
          _shipButton(),
        ],
      ],
    );
  }

  /// The app bar's buttons: save, share, report.
  List<Widget> _headerActions(BuildContext context) {
    final listing = _listing;
    return [
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
                  return Listener(
                    onPointerDown: (e) => _sharePointer = e.kind,
                    child: CircleAvatar(
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
    ];
  }

  /// The desktop page: the photos and everything long — details,
  /// description, tips, related items — in a column that scrolls, and beside
  /// it a sticky one with the key facts, the buttons and the seller.
  ///
  /// On a phone the gallery is a 320px header the page scrolls over, which at
  /// 1440px wide became a letterbox strip cropping every photo to its middle.
  /// And with the words and buttons in one column beside the photos, a long
  /// description pushed the buttons off the screen.
  Widget _buildWide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _listing?.title ?? widget.title;
    final side = frameInsets(context, min: 32);
    final seller = _sellerCard();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: _headerActions(context),
      ),
      body: Padding(
        padding: side,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWideGallery(context, scheme),
                          ..._bodySections(
                            context,
                            _detailsOf(context),
                            columns: context.isLargeLayout ? 2 : 1,
                            descriptionLines: 8,
                          ),
                          const Divider(height: 56),
                          _relatedHeader(context),
                        ],
                      ),
                    ),
                  ),
                  _buildRelatedSection(padding: EdgeInsets.zero),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Its own scroll, which only moves when the column is taller than
            // the window: the buttons stay put however long the page gets.
            SizedBox(
              width: 380,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _keyFactsCard(context, actions: _buildActions(context)),
                      ..._escrowBand(context),
                      if (seller != null) ...[
                        const SizedBox(height: 16),
                        seller,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The gallery at 4:3 with the whole photo showing, arrows to step through
  /// it with a mouse, and thumbnails underneath.
  Widget _buildWideGallery(BuildContext context, ColorScheme scheme) {
    final count = _imageList.length;
    void go(int index) {
      if (!_pageController.hasClients) return;
      _pageController.animateToPage(
        index.clamp(0, count - 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildGallery(context, scheme, fit: BoxFit.contain),
                  if (count > 1) ...[
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          tooltip: MaterialLocalizations.of(context)
                              .previousPageTooltip,
                          onPressed: _currentImageIndex > 0
                              ? () => go(_currentImageIndex - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          tooltip:
                              MaterialLocalizations.of(context).nextPageTooltip,
                          onPressed: _currentImageIndex < count - 1
                              ? () => go(_currentImageIndex + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _currentImageIndex;
                return Tappable(
                  onTap: () => go(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? context.tokens.accentInk
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: CachedNetworkImageProvider(_imageList[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
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

  /// Shown on every product, not only the ones payable here.
  ///
  /// Restricting it to company products meant the one place somebody is
  /// already looking at a thing they want was also the place the option was
  /// usually missing — and "can I pay for this on the platform" is a different
  /// question from "can you get this to me". Only the server-side switch and
  /// the kind gate it now.
  ///
  /// The kind check is not cosmetic: before 0048 every listing was a product,
  /// so a job advert carried a working "ship this item" button that opened a
  /// courier request for a vacancy.
  ///
  /// The category can switch it off as well (`listing_guide.delivery`): a
  /// plot of land is filed as a product, and nobody ships one.
  bool get _showsShipping =>
      _listing != null &&
      _listing!.isProduct &&
      _guide.delivery &&
      ShippingRepository.instance.enabled;

  Widget _shipButton() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 50,
      height: 50,
      child: OutlinedButton(
        onPressed: _shipThis,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Tooltip(
          message: context.l10n.shipFabLabel,
          child: Icon(Icons.local_shipping_outlined,
              size: 22, color: context.tokens.accentInk),
        ),
      ),
    );
  }

  /// Straight into the request with this product already chosen — the picker
  /// and the "what would you like shipped" question are both already answered
  /// by being here.
  Future<void> _shipThis() async {
    final listing = _listing;
    if (listing == null) return;
    if (!await requireAccount(context, context.l10n.shipSignInRequired,
        returnToListing: listing.id)) {
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShippingRequestScreen(initialListing: listing),
      ),
    );
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

    // Worded for the category — "Ask for a visit" on a flat, "Apply" on a
    // job — but every one opens the same chat.
    final l10n = context.l10n;
    final label = Text(
      switch (_guide.cta) {
        'quote' => l10n.ctaQuote,
        'apply' => l10n.ctaApply,
        'visit' => l10n.ctaVisit,
        _ => l10n.detailMessageSeller,
      },
      textAlign: TextAlign.center,
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

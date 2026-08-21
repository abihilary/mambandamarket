import 'package:flutter/material.dart';

import '../Screens/EditProfileScreen.dart';
import '../Screens/PublicProfileScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'CreateListingScreen.dart';
import '../Components/local_image.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _activeItems = [];
  final List<Map<String, dynamic>> _soldItems = [];

  bool _isLoading = true;
  String? _error;
  int _earnedCents = 0;
  api.SellerDashboard? _stats;

  static const String _kSignInError = '__seller_dash_sign_in__';
  static const String _kLoadError = '__seller_dash_load__';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _fromListing(api.Listing l) => {
    'id': l.id,
    'title': l.title,
    'priceLabel': l.displayPrice,
    'category': l.categorySlug,
    'condition': l.condition ?? '',
    'hasGuarantee': l.hasGuarantee,
    'views': l.viewCount,
    'inquiries': l.inquiryCount,
    'quantity': l.quantity,
    'images': l.imageUrls,
    'priceCents': l.priceCents,
    'inStock': l.quantity > 0,
  };

  Map<String, dynamic> _fromSale(api.Sale s) => {
    'id': s.listing?.id ?? s.id,
    'saleId': s.id,
    'title': s.listing?.title ?? '',
    'priceLabel': s.displayPrice,
    'category': s.listing?.categorySlug ?? '',
    'condition': '',
    'soldDate': s.soldAt == null
        ? ''
        : '${s.soldAt!.day}/${s.soldAt!.month}/${s.soldAt!.year}',
    'buyerName': s.buyer?.displayName ?? '',
    'images': s.listing?.imageUrls ?? const <String>[],
  };

  Future<void> _load() async {
    final uid = AuthService.instance.userId;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _error = _kSignInError;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ListingsRepository.instance;
      final results = await Future.wait([
        repo.sellerListings(uid, status: 'active'),
        repo.sales(uid),
        repo.dashboard(uid),
      ]);
      if (!mounted) return;
      final listings = results[0] as List<api.Listing>;
      final sales = results[1] as ({List<api.Sale> items, int totalCents});
      setState(() {
        _activeItems
          ..clear()
          ..addAll(listings.map(_fromListing));
        _soldItems
          ..clear()
          ..addAll(sales.items.map(_fromSale));
        _earnedCents = sales.totalCents;
        _earnedCurrency = sales.items.isNotEmpty
            ? (sales.items.first.listing?.currency ?? 'XAF')
            : (listings.isNotEmpty ? listings.first.currency : 'XAF');
        _stats = results[2] as api.SellerDashboard;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = _kLoadError;
          _isLoading = false;
        });
      }
    }
  }

  String _earnedCurrency = 'XAF';
  String get _totalEarnedLabel =>
      api.formatPrice(_earnedCents, currency: _earnedCurrency);

  Widget _buildImageWidget(String path) {
    final scheme = Theme.of(context).colorScheme;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 75,
          height: 75,
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      return LocalImage(
        path,
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 75,
          height: 75,
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
        ),
      );
    }
  }

  void _openCreateListingModal() async {
    final l10n = context.l10n;
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateListingScreen()),
    );

    if (created != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sellerDashListedSuccess)),
      );
    }
  }

  Future<void> _markItemAsSold(Map<String, dynamic> item) async {
    final l10n = context.l10n;
    try {
      await ListingsRepository.instance
          .markSold(item['id'] as String, soldPriceCents: item['priceCents'] as int?);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sellerDashMarkedSold(item['title'] as String))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }

  /// Edit a listing.
  ///
  /// This used to open the seller sign-up form with the listing handed over as
  /// a route argument nothing on the other side ever read — so "Edit" on an
  /// item showed an empty onboarding page and no way back to the item. The
  /// create screen has always doubled as the editor; it is what the business
  /// dashboard calls.
  Future<void> _editItem(Map<String, dynamic> item) async {
    final l10n = context.l10n;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(initialListing: item),
      ),
    );
    if (updated == null) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.sellerDashItemUpdated)),
    );
  }

  void _deleteItem(Map<String, dynamic> item, bool isActive) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sellerDashDeleteTitle),
        content: Text(l10n.sellerDashDeleteConfirm(item['title'] as String)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.sellerDashCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ListingsRepository.instance.delete(item['id'] as String);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.sellerDashListingDeleted)),
                );
              } on ApiException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppColors.danger),
                );
              }
            },
            child: Text(l10n.sellerDashDelete,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.sellerDashTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.sellerDashHomeTooltip,
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                    (route) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListingModal,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
          context.l10n.sellerDashSellItem,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PROFILE CARD WITH DUAL BUTTONS
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSellerHeaderCard(theme, context),
            ),

            // STATS SUMMARY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashActiveItems,
                      value: '${_activeItems.length}',
                      icon: Icons.sell_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashTotalEarned,
                      value: _totalEarnedLabel,
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashTotalViews,
                      value: '${_stats?.totalViews ?? 0}',
                      icon: Icons.visibility_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashInquiries,
                      value: '${_stats?.inquiries ?? 0}',
                      icon: Icons.chat_bubble_outline,
                      color: AppColors.glow,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TAB BAR
            TabBar(
              controller: _tabController,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(text: context.l10n.sellerDashActiveTab(_activeItems.length)),
                Tab(text: context.l10n.sellerDashSoldTab(_soldItems.length)),
              ],
            ),

            // TAB BAR VIEWS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveListingsTab(theme),
                  _buildSoldListingsTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  /// The card at the top of the hub: who you are, how much of your allowance
  /// is left, and the two things you do to your own profile.
  ///
  /// It used to be fixed text — "Personal Seller Account", "Individual Tier •
  /// Member since 2026" — which read as real information and was not. Now that
  /// every account reaches this screen, it shows the account actually signed in.
  Widget _buildSellerHeaderCard(ThemeData theme, BuildContext context) {
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return ValueListenableBuilder<api.Me?>(
      valueListenable: AuthService.instance.me,
      builder: (context, me, _) {
        final profile = me?.profile;
        final avatar = profile?.avatarUrl;
        final name = profile?.displayName?.isNotEmpty == true
            ? profile!.displayName!
            : l10n.sellerDashAccountName;

        // What is left of the allowance. This is the number that decides
        // whether the Sell button works, so it belongs where selling starts.
        // Null while /me is still in flight — better a line that is not there
        // yet than a made-up one.
        final remaining = me?.remainingListings;
        final subtitle = me == null
            ? null
            : remaining == null
                ? l10n.sellerDashListingsUnlimited
                : l10n.sellerDashListingsLeft(remaining < 0 ? 0 : remaining);

        final badge = _accountBadge(profile, l10n);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.warning,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar != null && avatar.isNotEmpty)
                        ? null
                        : const Icon(Icons.person,
                            color: AppColors.ink, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (badge != null)
                    Chip(
                      label: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                      backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Edit the profile itself. This used to open the seller
                  // sign-up form, which saved a role change on the way past —
                  // a buyer who tapped it came out the other side a seller.
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openEditProfile,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(l10n.editProfileTitle),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // See what everybody else sees, from the same endpoint they
                  // see it through — not a mock-up of it.
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPublicProfile(name),
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: Text(l10n.sellerDashViewProfile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The tag beside the name. A plain buyer gets none: there is nothing to
  /// announce, and inventing a tier for them is how the old card went wrong.
  String? _accountBadge(api.Profile? profile, AppLocalizations l10n) {
    if (profile == null) return null;
    if (profile.isCompany) return l10n.sellerDashCompanyBadge;
    if (profile.isBusiness) return l10n.sellerDashBusinessBadge;
    if (profile.isSeller) return l10n.sellerDashIndividualBadge;
    return null;
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  void _openPublicProfile(String name) {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: uid, initialName: name),
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                title,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _gate() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      final l10n = context.l10n;
      final message = _error == _kSignInError
          ? l10n.sellerDashSignInPrompt
          : _error == _kLoadError
          ? l10n.sellerDashLoadError
          : _error!;
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 44, color: muted),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _load, child: Text(l10n.sellerDashTryAgain)),
            ],
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildActiveListingsTab(ThemeData theme) {
    final scheme = theme.colorScheme;
    final gate = _gate();
    if (gate != null) return gate;
    if (_activeItems.isEmpty) {
      return Center(
        child: Text(
          context.l10n.sellerDashNoActiveItems,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeItems.length,
      itemBuilder: (context, index) {
        final item = _activeItems[index];
        final List<String> images = List<String>.from(item['images'] ?? []);
        final String mainImage = images.isNotEmpty
            ? images.first
            : 'https://picsum.photos/300/200';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(mainImage),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.sellerDashImgsCount(images.length),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['category'] ?? context.l10n.sellerDashGeneralCategory,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['priceLabel'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n
                                .sellerDashViewsCount(item['views'] as int? ?? 0),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.chat_bubble_outline,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.sellerDashChatsCount(
                                item['inquiries'] as int? ?? 0),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'mark_sold') {
                      _markItemAsSold(item);
                    } else if (value == 'edit') {
                      _editItem(item);
                    } else if (value == 'delete') {
                      _deleteItem(item, true);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'mark_sold',
                      child: Text(context.l10n.sellerDashMarkAsSold),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.l10n.sellerDashEdit),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.l10n.sellerDashDelete,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoldListingsTab(ThemeData theme) {
    final scheme = theme.colorScheme;
    final gate = _gate();
    if (gate != null) return gate;
    if (_soldItems.isEmpty) {
      return Center(
        child: Text(
          context.l10n.sellerDashNoSoldItems,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _soldItems.length,
      itemBuilder: (context, index) {
        final item = _soldItems[index];
        final List<String> images = List<String>.from(item['images'] ?? []);
        final String mainImage = images.isNotEmpty
            ? images.first
            : 'https://picsum.photos/300/200';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageWidget(mainImage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['title'] as String).isEmpty
                            ? context.l10n.sellerDashSoldItemFallback
                            : item['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['category'] ?? context.l10n.sellerDashGeneralCategory,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['priceLabel'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.sellerDashSoldTo(
                            (item['buyerName'] as String).isEmpty
                                ? context.l10n.sellerDashBuyerFallback
                                : item['buyerName'] as String,
                            item['soldDate'] as String),
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteItem(item, false);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.sellerDashDelete,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';

import '../Screens/IndividualSellerOnboardingScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import 'CreateListingScreen.dart';


class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // The render code below is map-driven, so the API models are adapted into
  // that shape rather than rewriting every row widget. Prices arrive
  // pre-formatted (`priceLabel`) because listings are priced in XAF and the
  // original UI hardcoded a dollar sign.
  final List<Map<String, dynamic>> _activeItems = [];
  final List<Map<String, dynamic>> _soldItems = [];

  bool _isLoading = true;
  String? _error;
  int _earnedCents = 0;
  api.SellerDashboard? _stats;

  // `_load` runs from initState, where a BuildContext isn't safe to localize.
  // It records these sentinels instead, which `_gate()` translates at build
  // time. Real API errors are stored verbatim and shown as-is.
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
      };

  Map<String, dynamic> _fromSale(api.Sale s) => {
        'id': s.listing?.id ?? s.id,
        'saleId': s.id,
        'title': s.listing?.title ?? 'Article vendu',
        'priceLabel': s.displayPrice,
        'category': s.listing?.categorySlug ?? '',
        'condition': '',
        'soldDate': s.soldAt == null
            ? ''
            : '${s.soldAt!.day}/${s.soldAt!.month}/${s.soldAt!.year}',
        'buyerName': s.buyer?.displayName ?? 'Acheteur',
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

  /// Earnings in the currency the items were actually priced in, rather than
  /// the dollar sign the template hardcoded.
  String _earnedCurrency = 'XAF';
  String get _totalEarnedLabel =>
      api.formatPrice(_earnedCents, currency: _earnedCurrency);

  // Helper method to display either Network or File images seamlessly
  Widget _buildImageWidget(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 75,
          height: 75,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(path),
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 75,
          height: 75,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }

  // Open CreateListingScreen; it publishes through the API itself, so we just
  // reload to pick the new item up with its server-assigned fields.
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
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  // Handle Edit Action
  void _editItem(Map<String, dynamic> item) {
    // Navigates to onboarding screen, passing existing item details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IndividualSellerOnboardingScreen(),
        settings: RouteSettings(arguments: item),
      ),
    );
  }

  // Handle Delete Action
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
                // Soft-delete server-side, then reload so the tabs reflect
                // what the server actually holds.
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
                      backgroundColor: Colors.red.shade700),
                );
              }
            },
            child: Text(l10n.sellerDashDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
          context.l10n.sellerDashSellItem,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PROFILE CARD
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
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashTotalEarned,
                      value: _totalEarnedLabel,
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Reach figures come from the dashboard endpoint, which aggregates
            // server-side rather than summing whatever page we happen to hold.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashTotalViews,
                      value: '${_stats?.totalViews ?? 0}',
                      icon: Icons.visibility_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      title: context.l10n.sellerDashInquiries,
                      value: '${_stats?.inquiries ?? 0}',
                      icon: Icons.chat_bubble_outline,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TAB BAR
            TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: theme.primaryColor,
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

  Widget _buildSellerHeaderCard(ThemeData theme, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.amber,
                child: Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.sellerDashAccountName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.sellerDashAccountTier,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  context.l10n.sellerDashIndividualBadge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                backgroundColor: Colors.amber.shade50,
                side: BorderSide.none,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                      (route) => false,
                );
              },
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text(context.l10n.sellerDashGoToMarketplace),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shared loading/error gate so a slow or failed fetch is distinguishable
  /// from genuinely having nothing listed.
  Widget? _gate() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      final l10n = context.l10n;
      final message = _error == _kSignInError
          ? l10n.sellerDashSignInPrompt
          : _error == _kLoadError
              ? l10n.sellerDashLoadError
              : _error!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
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
    final gate = _gate();
    if (gate != null) return gate;
    if (_activeItems.isEmpty) {
      return Center(
        child: Text(
          context.l10n.sellerDashNoActiveItems,
          style: TextStyle(color: Colors.grey.shade600),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
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
                            color: Colors.black.withOpacity(0.7),
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
                        item['category'] ?? 'General',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.indigo.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['priceLabel'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n
                                .sellerDashViewsCount(item['views'] as int? ?? 0),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.chat_bubble_outline,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.sellerDashChatsCount(
                                item['inquiries'] as int? ?? 0),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
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
                        style: const TextStyle(color: Colors.red),
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
    final gate = _gate();
    if (gate != null) return gate;
    if (_soldItems.isEmpty) {
      return Center(
        child: Text(
          context.l10n.sellerDashNoSoldItems,
          style: TextStyle(color: Colors.grey.shade600),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
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
                        item['category'] ?? 'General',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.indigo.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['priceLabel'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.sellerDashSoldTo(
                            item['buyerName'] as String,
                            item['soldDate'] as String),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteItem(item, false);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.sellerDashDelete,
                          style: const TextStyle(color: Colors.red)),
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
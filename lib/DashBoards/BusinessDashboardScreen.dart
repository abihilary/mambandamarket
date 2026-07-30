import 'dart:io';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart' as api;
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import 'CreateListingScreen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  // Stable, non-localized filter keys. These drive the filtering logic and the
  // DropdownButton's `value`; only their display labels are localized, so the
  // state stays language-independent.
  static const String _filterAll = 'All';
  static const String _filterInStock = 'In Stock';
  static const String _filterOutOfStock = 'Out of Stock';

  // Sentinels stored in [_error] for failures raised from initState's _load(),
  // where context.l10n isn't available; build() translates them for display.
  static const String _signInSentinel = '__signin__';
  static const String _networkErrorSentinel = '__network__';

  String _selectedFilter = _filterAll;

  // Inventory comes from the seller's own feed, which unlike public browse
  // includes sold and hidden items and carries per-listing inquiry counts.
  // Rows are rendered from maps, so API models are adapted rather than
  // rewriting every widget; `priceLabel` is pre-formatted because listings are
  // priced in XAF and this screen originally hardcoded a dollar sign.
  final List<Map<String, dynamic>> _mockInventory = [];

  bool _isLoading = true;
  String? _error;
  api.Store? _store;
  api.SellerDashboard? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _adapt(api.Listing l) => {
        'id': l.id,
        'title': l.title,
        'priceLabel': l.displayPrice,
        'priceCents': l.priceCents,
        'quantity': l.quantity,
        'category': l.categorySlug,
        'category_slug': l.categorySlug,
        'condition': l.condition ?? '',
        'hasGuarantee': l.hasGuarantee,
        'views': l.viewCount,
        'inStock': l.quantity > 0,
        'status': l.status,
        'currency': l.currency,
        'images': l.imageUrls,
      };

  /// Currency of the inventory, so revenue isn't rendered with a stray symbol.
  String get _storeCurrency => _mockInventory.isEmpty
      ? 'XAF'
      : (_mockInventory.first['currency'] as String? ?? 'XAF');

  Future<void> _load() async {
    final uid = AuthService.instance.userId;
    if (uid == null) {
      setState(() { _isLoading = false; _error = _signInSentinel; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        ListingsRepository.instance.sellerListings(uid, status: 'all'),
        ListingsRepository.instance.dashboard(uid),
        StoresRepository.instance.mine(),
      ]);
      if (!mounted) return;
      final listings = (results[0] as List<api.Listing>)
          .where((l) => l.status != 'deleted')
          .toList();
      setState(() {
        _mockInventory
          ..clear()
          ..addAll(listings.map(_adapt));
        _stats = results[1] as api.SellerDashboard;
        _store = results[2] as api.Store?;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = _networkErrorSentinel;
          _isLoading = false;
        });
      }
    }
  }

  // Open Create Modal
  void _openCreateListingModal() async {
    final l10n = context.l10n;
    final newItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateListingScreen()),
    );

    if (newItem != null) {
      await _load();
      _showSnackBar(l10n.bizDashListingCreated);
    }
  }

  // Open Edit Modal
  void _openEditListingModal(Map<String, dynamic> item, int index) async {
    final l10n = context.l10n;
    final updatedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(initialListing: item),
      ),
    );

    if (updatedItem != null) {
      await _load();
      _showSnackBar(l10n.bizDashItemUpdated);
    }
  }

  // Delete Item Confirmation Dialog
  void _confirmDeleteItem(String id, String title) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bizDashDeleteTitle),
        content: Text(l10n.bizDashDeleteConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.bizDashCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ListingsRepository.instance.delete(id);
                await _load();
                _showSnackBar(l10n.bizDashItemDeleted);
              } on ApiException catch (e) {
                _showSnackBar(e.message);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.bizDashDelete),
          ),
        ],
      ),
    );
  }

  void _navigateToEditStore() {
    Navigator.pushNamed(context, '/bussiness');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<Map<String, dynamic>> get _filteredInventory {
    if (_selectedFilter == _filterInStock) {
      return _mockInventory.where((i) => i['inStock'] == true).toList();
    } else if (_selectedFilter == _filterOutOfStock) {
      return _mockInventory.where((i) => i['inStock'] == false).toList();
    }
    return _mockInventory;
  }

  /// Localized display label for a stable filter key.
  String _filterLabel(BuildContext context, String filter) {
    switch (filter) {
      case _filterInStock:
        return context.l10n.bizDashFilterInStock;
      case _filterOutOfStock:
        return context.l10n.bizDashFilterOutOfStock;
      default:
        return context.l10n.bizDashFilterAll;
    }
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedList = _filteredInventory;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.bizDashTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.bizDashGoToHomeFeed,
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _navigateToEditStore,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListingModal,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
          context.l10n.bizDashAddNewItem,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreHeaderCard(theme, context),
            const SizedBox(height: 20),
            Text(
              context.l10n.bizDashPerformanceOverview,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatsOverview(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.bizDashActiveListings(displayedList.length),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list),
                  items: [_filterAll, _filterInStock, _filterOutOfStock]
                      .map((filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(_filterLabel(context, filter),
                        style: const TextStyle(fontSize: 14)),
                  ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                        _error == _signInSentinel
                            ? context.l10n.bizDashSignInPrompt
                            : _error == _networkErrorSentinel
                                ? context.l10n.bizDashLoadError
                                : _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: Text(context.l10n.bizDashTryAgain)),
                  ],
                ),
              )
            else if (displayedList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    _selectedFilter == _filterAll
                        ? context.l10n.bizDashNoItems
                        : context.l10n.bizDashNoMatch(
                            _filterLabel(context, _selectedFilter)),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedList.length,
                itemBuilder: (context, index) {
                  final item = displayedList[index];
                  return _buildInventoryCard(item, index, theme);
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeaderCard(ThemeData theme, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: const DecorationImage(
                image: NetworkImage('https://picsum.photos/600/200?store=1'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.indigo.shade50,
                      backgroundImage: const NetworkImage('https://picsum.photos/100/100?logo=1'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _store?.shopName ?? context.l10n.bizDashYourStore,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Only badge stores the backend actually marked verified.
                              if (_store?.isVerified == true)
                                Icon(Icons.verified, size: 16, color: theme.primaryColor),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _store == null
                                ? context.l10n.bizDashSetupStorefront
                                : '${_store!.isVerified ? context.l10n.bizDashVerifiedMerchant : ""}'
                                    '${_store!.ratingAvg.toStringAsFixed(1)} ★ '
                                    '(${context.l10n.bizDashReviewsCount(_store!.ratingCount)})',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                        },
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: Text(context.l10n.bizDashGoToHomeMarketplace),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _navigateToEditStore,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(context.l10n.bizDashEditStore,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
              title: context.l10n.bizDashTotalRevenue,
              value: api.formatPrice(_stats?.earningsCents ?? 0, currency: _storeCurrency),
              icon: Icons.payments_outlined,
              color: Colors.green),
          const SizedBox(width: 12),
          _buildStatCard(
              title: context.l10n.bizDashItemsSold,
              value: context.l10n.bizDashUnitsCount(_stats?.soldListings ?? 0),
              icon: Icons.shopping_bag_outlined,
              color: Colors.blue),
          const SizedBox(width: 12),
          _buildStatCard(
              title: context.l10n.bizDashStoreVisits,
              value: '${_stats?.totalViews ?? 0}',
              icon: Icons.visibility_outlined,
              color: Colors.orange),
          const SizedBox(width: 12),
          _buildStatCard(
              title: context.l10n.bizDashInquiries,
              value: '${_stats?.inquiries ?? 0}',
              icon: Icons.chat_bubble_outline,
              color: Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item, int index, ThemeData theme) {
    final List<String> images = List<String>.from(item['images'] ?? []);
    final String mainImage = images.isNotEmpty ? images.first : 'https://picsum.photos/300/200';
    final int quantity = item['quantity'] ?? 1;

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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.l10n.bizDashImagesCount(images.length),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item['category'] ?? context.l10n.bizDashGeneralCategory,
                        style: TextStyle(fontSize: 11, color: Colors.indigo.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.bizDashQty(quantity),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['priceLabel'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.primaryColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item['condition'], style: TextStyle(fontSize: 10, color: Colors.grey.shade800)),
                      ),
                      const SizedBox(width: 6),
                      if (item['hasGuarantee'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.bizDashGuarantee,
                            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditListingModal(item, index);
                } else if (value == 'delete') {
                  _confirmDeleteItem(item['id'], item['title']);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(context.l10n.bizDashEditItem)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.bizDashDeleteItem,
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
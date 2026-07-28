import 'dart:io';
import 'package:flutter/material.dart';
import '../Screens/IndividualSellerOnboardingScreen.dart';
import 'CreateListingScreen.dart';


class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _activeItems = [
    {
      'id': '101',
      'title': 'iPhone Pro (128GB) - Graphite',
      'price': 520.0,
      'category': 'Elektronik',
      'condition': 'Used',
      'hasGuarantee': false,
      'views': 128,
      'inquiries': 5,
      'datePosted': '2 days ago',
      'images': [
        'https://picsum.photos/300/200?random=11',
        'https://picsum.photos/300/200?random=110',
      ],
    },
    {
      'id': '102',
      'title': 'Mountain Bike (27.5" Wheels)',
      'price': 180.0,
      'category': 'Sport',
      'condition': 'Like New',
      'hasGuarantee': false,
      'views': 45,
      'inquiries': 2,
      'datePosted': '5 days ago',
      'images': [
        'https://picsum.photos/300/200?random=12',
      ],
    },
  ];

  final List<Map<String, dynamic>> _soldItems = [
    {
      'id': '103',
      'title': 'Sony WH-1000XM4 Headphones',
      'price': 140.0,
      'category': 'Elektronik',
      'condition': 'Used',
      'soldDate': 'Jul 18, 2026',
      'buyerName': 'Sarah M.',
      'images': [
        'https://picsum.photos/300/200?random=13',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Calculate total earnings dynamically from sold items
  double get _totalEarned {
    return _soldItems.fold(0.0, (sum, item) => sum + (item['price'] as double? ?? 0.0));
  }

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

  // Open CreateListingScreen & receive newly created item
  void _openCreateListingModal() async {
    final newItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateListingScreen()),
    );

    if (newItem != null) {
      setState(() {
        _activeItems.insert(0, newItem);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item listed for sale successfully!')),
      );
    }
  }

  // Handle Mark as Sold
  void _markItemAsSold(Map<String, dynamic> item) {
    setState(() {
      _activeItems.removeWhere((element) => element['id'] == item['id']);

      // Update item metadata for sold status
      final soldItem = Map<String, dynamic>.from(item);
      soldItem['soldDate'] = 'Today';
      soldItem['buyerName'] = 'Marketplace Buyer';

      _soldItems.insert(0, soldItem);
    });

    // TODO: Send backend update: API request to update item status to "SOLD" in DB

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${item['title']}" marked as sold!')),
    );
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: Text('Are you sure you want to delete "${item['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (isActive) {
                  _activeItems.removeWhere((e) => e['id'] == item['id']);
                } else {
                  _soldItems.removeWhere((e) => e['id'] == item['id']);
                }
              });

              // TODO: Send backend update: API request to DELETE item from DB

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        title: const Text(
          'My Seller Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Go to Home Feed',
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
        label: const Text(
          'Sell Item',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                      title: 'Active Items',
                      value: '${_activeItems.length}',
                      icon: Icons.sell_outlined,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      title: 'Total Earned',
                      value: '\$${_totalEarned.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
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
                Tab(text: 'Active Listings (${_activeItems.length})'),
                Tab(text: 'Sold (${_soldItems.length})'),
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
                    const Text(
                      'Personal Seller Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Individual Tier • Member since 2026',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Chip(
                label: const Text(
                  'INDIVIDUAL',
                  style: TextStyle(
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
              label: const Text('Go to Home Marketplace'),
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

  Widget _buildActiveListingsTab(ThemeData theme) {
    if (_activeItems.isEmpty) {
      return Center(
        child: Text(
          'No active items listed yet.',
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
                            '${images.length} imgs',
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
                        '\$${item['price'].toStringAsFixed(2)}',
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
                            '${item['views'] ?? 0} views',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.chat_bubble_outline,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${item['inquiries'] ?? 0} chats',
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
                    const PopupMenuItem(
                      value: 'mark_sold',
                      child: Text('Mark as Sold'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
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
    if (_soldItems.isEmpty) {
      return Center(
        child: Text(
          'No sold items yet.',
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
                        '\$${item['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sold to ${item['buyerName']} on ${item['soldDate']}',
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
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
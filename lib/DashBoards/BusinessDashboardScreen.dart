import 'dart:io';
import 'package:flutter/material.dart';

import 'CreateListingScreen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _mockInventory = [
    {
      'id': '1',
      'title': 'Toyota Land Cruiser V8 (2022)',
      'price': 65000.0,
      'quantity': 1,
      'category': 'Auto & Rad',
      'condition': 'Like New',
      'hasGuarantee': true,
      'views': 412,
      'inStock': true,
      'images': [
        'https://picsum.photos/300/200?random=1',
        'https://picsum.photos/300/200?random=11',
      ],
    },
    {
      'id': '2',
      'title': 'MacBook Pro 16" M3 Max (64GB RAM)',
      'price': 3499.0,
      'quantity': 3,
      'category': 'Elektronik',
      'condition': 'New',
      'hasGuarantee': true,
      'views': 890,
      'inStock': true,
      'images': [
        'https://picsum.photos/300/200?random=2',
        'https://picsum.photos/300/200?random=12',
      ],
    },
    {
      'id': '3',
      'title': 'Samsung 65" Neo QLED 4K TV',
      'price': 1200.0,
      'quantity': 0,
      'category': 'Elektronik',
      'condition': 'Refurbished',
      'hasGuarantee': true,
      'views': 230,
      'inStock': false,
      'images': [
        'https://picsum.photos/300/200?random=3',
      ],
    },
  ];

  // Open Create Modal
  void _openCreateListingModal() async {
    final newItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateListingScreen()),
    );

    if (newItem != null) {
      setState(() {
        _mockInventory.insert(0, newItem);
      });
      _showSnackBar('Listing created successfully!');
    }
  }

  // Open Edit Modal
  void _openEditListingModal(Map<String, dynamic> item, int index) async {
    final updatedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(initialListing: item),
      ),
    );

    if (updatedItem != null) {
      setState(() {
        _mockInventory[index] = updatedItem;
      });
      _showSnackBar('Item updated successfully!');
    }
  }

  // Delete Item Confirmation Dialog
  void _confirmDeleteItem(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _mockInventory.removeWhere((item) => item['id'] == id);
              });
              _showSnackBar('Item deleted successfully');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
    if (_selectedFilter == 'In Stock') {
      return _mockInventory.where((i) => i['inStock'] == true).toList();
    } else if (_selectedFilter == 'Out of Stock') {
      return _mockInventory.where((i) => i['inStock'] == false).toList();
    }
    return _mockInventory;
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
        title: const Text(
          'Store Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Go to Home Feed',
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
        label: const Text(
          'Add New Item',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              'Performance Overview',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatsOverview(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Listings (${displayedList.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list),
                  items: ['All', 'In Stock', 'Out of Stock']
                      .map((filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(filter, style: const TextStyle(fontSize: 14)),
                  ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                              const Text(
                                'Apex Auto & Tech Store',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.verified, size: 16, color: theme.primaryColor),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verified Merchant • 4.9 ★ (128 Reviews)',
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
                        label: const Text('Go to Home Marketplace'),
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
                      child: const Text('Edit Store', style: TextStyle(fontSize: 12)),
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
          _buildStatCard(title: 'Total Revenue', value: '\$84,250', icon: Icons.payments_outlined, color: Colors.green),
          const SizedBox(width: 12),
          _buildStatCard(title: 'Items Sold', value: '42 Units', icon: Icons.shopping_bag_outlined, color: Colors.blue),
          const SizedBox(width: 12),
          _buildStatCard(title: 'Store Visits', value: '3,840', icon: Icons.visibility_outlined, color: Colors.orange),
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
                        '${images.length} imgs',
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
                        item['category'] ?? 'General',
                        style: TextStyle(fontSize: 11, color: Colors.indigo.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Qty: $quantity',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${item['price'].toStringAsFixed(2)}',
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
                          child: const Text(
                            'Guarantee',
                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
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
                const PopupMenuItem(value: 'edit', child: Text('Edit Item')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Item', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
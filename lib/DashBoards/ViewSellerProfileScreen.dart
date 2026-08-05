import 'dart:io';
import 'package:flutter/material.dart';
import '../api/models.dart' as api;
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

class ViewSellerProfileScreen extends StatelessWidget {
  final api.SellerDashboard? sellerStats;
  final String? sellerName;
  final List<Map<String, dynamic>> inventory;

  const ViewSellerProfileScreen({
    super.key,
    this.sellerStats,
    this.sellerName,
    required this.inventory,
  });

  void _onProductTap(BuildContext context, Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing: ${item['title']}')),
    );
  }

  List<Map<String, dynamic>> get _displayInventory {
    if (inventory.isNotEmpty) return inventory;
    return [
      {
        'id': 'sample_1',
        'title': 'Sample Item 1',
        'priceLabel': '15,000 XAF',
        'quantity': 1,
        'category': 'Electronics',
        'condition': 'Used - Like New',
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=10'],
      },
      {
        'id': 'sample_2',
        'title': 'Sample Item 2',
        'priceLabel': '8,500 XAF',
        'quantity': 1,
        'category': 'Fashion',
        'condition': 'Good Condition',
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=11'],
      },
      {
        'id': 'sample_3',
        'title': 'Sample Item 3',
        'priceLabel': '30,000 XAF',
        'quantity': 1,
        'category': 'Home',
        'condition': 'Refurbished',
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=12'],
      },
      {
        'id': 'sample_4',
        'title': 'Sample Item 4',
        'priceLabel': '5,000 XAF',
        'quantity': 0,
        'category': 'Accessories',
        'condition': 'Used',
        'inStock': false,
        'images': ['https://picsum.photos/300/300?random=13'],
      },
    ];
  }

  Widget _buildGridImage(String path) {
    Widget placeholder() => Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final itemsToDisplay = _displayInventory;
    final displayName = sellerName ?? l10n.sellerDashAccountName;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Individual Seller Profile Card Header (No Banner)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar & Name Row
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.warning,
                          child: Icon(Icons.person, color: AppColors.ink, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Chip(
                                    label: Text(
                                      l10n.sellerDashIndividualBadge,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                    backgroundColor:
                                    AppColors.warning.withValues(alpha: 0.12),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.sellerDashAccountTier,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Quick Stats Row
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sell_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${itemsToDisplay.length} Active Items',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sellerStats?.totalViews ?? 0} Views',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Welcome to my seller profile! Check out my available items below and feel free to reach out with any inquiries.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Listings Grid Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Listings (${itemsToDisplay.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2 x 2 Product Grid Layout
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: itemsToDisplay.length,
                    itemBuilder: (context, index) {
                      final item = itemsToDisplay[index];
                      return _buildGridProductCard(context, item, theme);
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridProductCard(
      BuildContext context,
      Map<String, dynamic> item,
      ThemeData theme,
      ) {
    final cs = theme.colorScheme;
    final List<String> images = List<String>.from(item['images'] ?? []);
    final String mainImage =
    images.isNotEmpty ? images.first : 'https://picsum.photos/300/300';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => _onProductTap(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildGridImage(mainImage),
                  if (item['inStock'] == false)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (item['priceLabel'] as String?) ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if ((item['condition'] as String?)?.isNotEmpty ?? false)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['condition'],
                            style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
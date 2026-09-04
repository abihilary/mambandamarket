import 'package:flutter/material.dart';
import '../api/models.dart' as api;
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/local_image.dart';
import '../Components/image_placeholder.dart';
import '../Components/rating_badge.dart';

class mySellerScreen extends StatelessWidget {
  final api.Store? store;
  final List<Map<String, dynamic>> inventory;

  const mySellerScreen({
    super.key,
    required this.store,
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
        'title': 'Sample Product 1',
        'priceLabel': '25,000 XAF',
        'quantity': 5,
        'category': 'Electronics',
        'condition': 'New',
        'hasGuarantee': true,
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=1'],
      },
      {
        'id': 'sample_2',
        'title': 'Sample Product 2',
        'priceLabel': '12,500 XAF',
        'quantity': 2,
        'category': 'Fashion',
        'condition': 'Used - Like New',
        'hasGuarantee': false,
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=2'],
      },
      {
        'id': 'sample_3',
        'title': 'Sample Product 3',
        'priceLabel': '45,000 XAF',
        'quantity': 1,
        'category': 'Home',
        'condition': 'Refurbished',
        'hasGuarantee': true,
        'inStock': true,
        'images': ['https://picsum.photos/300/300?random=3'],
      },
      {
        'id': 'sample_4',
        'title': 'Sample Product 4',
        'priceLabel': '8,000 XAF',
        'quantity': 10,
        'category': 'Accessories',
        'condition': 'New',
        'hasGuarantee': false,
        'inStock': false,
        'images': ['https://picsum.photos/300/300?random=4'],
      },
    ];
  }

  Widget _buildGridImage(String path) {
    // Themed, and shared with the other two profile screens that had the same
    // grey slab pasted into them.
    Widget placeholder() => const ImagePlaceholder();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    } else {
      return LocalImage(
        path,
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
    final storeDescription = store?.description;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          store?.shopName ?? l10n.bizDashYourStore,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Profile Card Header
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
                    // Avatar & Store Name Header Row
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.transparent,
                            backgroundImage: NetworkImage(
                              'https://picsum.photos/100/100?logo=1',
                            ),
                          ),
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
                                      store?.shopName ?? l10n.bizDashYourStore,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (store?.isVerified == true) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Shared, and legible on both grounds: raw
                                  // amber label text is 2.3:1 on white.
                                  RatingBadge(
                                    rating: store?.ratingAvg ?? 0,
                                    count: store?.ratingCount ?? 0,
                                    compact: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${l10n.bizDashReviewsCount(store?.ratingCount ?? 0)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Description Block
                    const SizedBox(height: 14),
                    Text(
                      (storeDescription != null && storeDescription.isNotEmpty)
                          ? storeDescription
                          : 'Welcome to our store! Browse through our collection of featured items.',
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

            // Products Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Products (${itemsToDisplay.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'All Inventory',
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
import 'package:flutter/material.dart';

/// A prototype showcase screen demonstrating category-native feed and product detail
/// presentations inspired by Kleinanzeigen / mobile.de design patterns across
/// all major categories, fully localized in English with sample products from Mambanda Market,
/// featuring a dedicated mobile.de-inspired vehicle prototype screen with zero layout bugs.
class CategoryPresentationPrototypesScreen extends StatefulWidget {
  const CategoryPresentationPrototypesScreen({super.key});

  @override
  State<CategoryPresentationPrototypesScreen> createState() =>
      _CategoryPresentationPrototypesScreenState();
}

class _CategoryPresentationPrototypesScreenState
    extends State<CategoryPresentationPrototypesScreen> {
  int _selectedTab = 0; // 0: Feed, 1: Electronics, 2: Vehicles, 3: Real Estate, 4: Home & Garden, 5: Fashion

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    switch (_selectedTab) {
      case 0:
        currentScreen = const _PrototypeHomeFeed();
        break;
      case 1:
        currentScreen = const _PrototypeElectronicsDetail();
        break;
      case 2:
        currentScreen = const _PrototypeVehicleDetail();
        break;
      case 3:
        currentScreen = const _PrototypeRealEstateDetail();
        break;
      case 4:
        currentScreen = const _PrototypeHomeGardenDetail();
        break;
      case 5:
        currentScreen = const _PrototypeFashionDetail();
        break;
      default:
        currentScreen = const _PrototypeHomeFeed();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Presentations Prototype (EN)'),
        backgroundColor: const Color(0xFF1B2A1E),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF142016),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _TabButton(
                    title: 'Home Feed',
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _TabButton(
                    title: 'Electronics',
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _TabButton(
                    title: 'Vehicles',
                    selected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                  _TabButton(
                    title: 'Real Estate',
                    selected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3),
                  ),
                  _TabButton(
                    title: 'Home & Garden',
                    selected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4),
                  ),
                  _TabButton(
                    title: 'Fashion',
                    selected: _selectedTab == 5,
                    onTap: () => setState(() => _selectedTab = 5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: currentScreen,
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF8CD867) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? const Color(0xFF8CD867) : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. HOME FEED PROTOTYPE (English, Mambanda Market samples)
// ============================================================================
class _PrototypeHomeFeed extends StatelessWidget {
  const _PrototypeHomeFeed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? const Color(0xFF181F1A) : const Color(0xFF1B2A1E),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C352E) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.search, color: Colors.grey, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search in Douala, Cameroon...',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C352E) : const Color(0xFF2A3D2F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Color(0xFF8CD867), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C352E) : const Color(0xFF2A3D2F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _CategoryPill(icon: Icons.local_florist, label: 'For You', selected: true),
                        _CategoryPill(icon: Icons.home_outlined, label: 'Real Estate', selected: false),
                        _CategoryPill(icon: Icons.chair_outlined, label: 'Home & Garden', selected: false),
                        _CategoryPill(icon: Icons.directions_car_outlined, label: 'Vehicles', selected: false),
                        _CategoryPill(icon: Icons.checkroom_outlined, label: 'Fashion', selected: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
              children: const [
                _ProductCardPrototype(
                  imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=500&q=80',
                  title: 'Littoral - Douala\nApple MacBook Pro 14 M1 Pro / 16GB / 512GB SSD...',
                  price: '650,000 FCFA',
                  shippingBadge: 'Shipping available',
                  directBuy: false,
                  discount: null,
                ),
                _ProductCardPrototype(
                  imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=500&q=80',
                  title: 'Littoral - Douala\nApple iPhone 13 Pro / 256 GB / Silver / Mint Condition',
                  price: '320,000 FCFA',
                  oldPrice: '380,000 FCFA',
                  directBuy: true,
                  discount: '-15%',
                  highlighted: true,
                ),
                _ProductCardPrototype(
                  imageUrl: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=500&q=80',
                  title: 'Littoral - Douala\nToyota Corolla 2.0 Hybrid / Automatic / 2021',
                  price: '11,500,000 FCFA',
                  shippingBadge: null,
                  directBuy: false,
                  discount: null,
                ),
                _ProductCardPrototype(
                  imageUrl: 'https://images.unsplash.com/photo-1526738549149-8e07eca6c147?w=500&q=80',
                  title: 'Littoral - Douala\nApple Watch Series 10 46mm Titanium Slate GPS',
                  price: '245,000 FCFA',
                  shippingBadge: 'Shipping available',
                  directBuy: true,
                  discount: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF8CD867) : const Color(0xFF2C352E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? Colors.black : Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCardPrototype extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String? oldPrice;
  final String? shippingBadge;
  final bool directBuy;
  final String? discount;
  final bool highlighted;

  const _ProductCardPrototype({
    required this.imageUrl,
    required this.title,
    required this.price,
    this.oldPrice,
    this.shippingBadge,
    required this.directBuy,
    this.discount,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: highlighted
            ? Border.all(color: const Color(0xFF8CD867), width: 3)
            : Border.all(color: Colors.grey.shade300),
        boxShadow: [
          if (highlighted)
            BoxShadow(
              color: const Color(0xFF8CD867).withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  imageUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => Container(
                    height: 130,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              if (directBuy)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E4620),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_user, color: Color(0xFF8CD867), size: 12),
                        SizedBox(width: 3),
                        Text(
                          'Direct Buy',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (discount != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      discount!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          if (oldPrice != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              oldPrice!,
                              style: const TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (shippingBadge != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              shippingBadge!,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ] else if (directBuy) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            '🛡️ Direct Buy',
                            style: TextStyle(fontSize: 9, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// HELPER FOR OVERLAPPING IMAGE-CARD LAYOUT
// ============================================================================
class _OverlappingDetailScaffold extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String imageCounter;
  final Widget bottomAction;
  final List<Widget> children;

  const _OverlappingDetailScaffold({
    required this.title,
    required this.imageUrl,
    required this.imageCounter,
    required this.bottomAction,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        actions: const [
          Icon(Icons.favorite_border, color: Colors.white),
          SizedBox(width: 16),
          Icon(Icons.share, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(imageCounter, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 240, bottom: 100),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomAction,
    );
  }
}


// ============================================================================
// 2. ELECTRONICS / PHONE PRODUCT DETAIL PROTOTYPE
// ============================================================================
class _PrototypeElectronicsDetail extends StatelessWidget {
  const _PrototypeElectronicsDetail();

  @override
  Widget build(BuildContext context) {
    return _OverlappingDetailScaffold(
      title: 'iPhone 13 Pro / 256 GB / Silv...',
      imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=800&q=80',
      imageCounter: '1 / 6',
      bottomAction: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181F1A),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text('Message', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.verified_user, color: Colors.black),
                label: const Text('Direct Buy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CD867),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFF8CD867), size: 14),
            SizedBox(width: 4),
            Text('Douala, Bonapriso', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Apple iPhone 13 Pro / 256 GB / Silver / Mint Condition',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Text('320,000 FCFA', style: TextStyle(color: Color(0xFF8CD867), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(width: 12),
            Text('380,000 FCFA', style: TextStyle(color: Colors.grey, fontSize: 16, decoration: TextDecoration.lineThrough)),
            SizedBox(width: 12),
            Text('Shipping from 2,000 FCFA', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('1 week ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.visibility_outlined, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('118 views', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B381D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF8CD867).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Protected with Mambanda Buyer Protection for 5,000 FCFA extra',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  _PayLogo(label: 'MTN MoMo', color: Colors.amber),
                  SizedBox(width: 6),
                  _PayLogo(label: 'Orange Money', color: Colors.orange),
                  SizedBox(width: 6),
                  _PayLogo(label: 'VISA', color: Colors.blue),
                  SizedBox(width: 6),
                  _PayLogo(label: 'Mastercard', color: Colors.orange),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const _DetailRow(label: 'Brand', value: 'Apple'),
        const _DetailRow(label: 'Model', value: 'iPhone 13 Pro'),
        const _DetailRow(label: 'Color', value: 'Silver'),
        const _DetailRow(label: 'Storage', value: '256 GB'),
        const _DetailRow(label: 'Condition', value: 'Mint Condition'),
        const _DetailRow(label: 'Operating System', value: 'iOS'),
        const _DetailRow(label: 'RAM', value: '6 GB'),
        const SizedBox(height: 20),
        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Selling my pristine iPhone 13 Pro in Silver with 256 GB storage. '
          'Always used with a case and tempered glass screen protector. Zero scratches. '
          'Battery health is at 88%. Original box and lightning cable included.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}


// ============================================================================
// 3. VEHICLE / CAR PRODUCT DETAIL PROTOTYPE (New mobile.de style layout without Stack sizing bugs)
// ============================================================================
class _PrototypeVehicleDetail extends StatelessWidget {
  const _PrototypeVehicleDetail();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181F1A),
        foregroundColor: Colors.white,
        title: const Text('Toyota Corolla Hybrid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        actions: const [
          Icon(Icons.favorite_border, color: Colors.white70, size: 18),
          SizedBox(width: 16),
          Icon(Icons.share, color: Colors.white70, size: 18),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Image Banner with counter
            Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=800&q=80',
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => Container(
                    height: 260,
                    color: const Color(0xFF2C352E),
                    child: const Center(
                      child: Icon(Icons.image, color: Color(0xFF8CD867), size: 48),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('1 / 8', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
            // 2. Vehicle Content Container (Standard Column flow, zero stack sizing bugs)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              transform: Matrix4.translationValues(0.0, -16.0, 0.0),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Color(0xFF8CD867), size: 14),
                      SizedBox(width: 4),
                      Text('Douala, Akwa', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toyota Corolla 2.0 Hybrid / Automatic / 2021',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Text('11,500,000 FCFA', style: TextStyle(color: Color(0xFF8CD867), fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(width: 12),
                      Text('12,200,000 FCFA', style: TextStyle(color: Colors.grey, fontSize: 16, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Calculate Financing (mobile.de style)',
                      style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('6 days ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(width: 16),
                      Icon(Icons.visibility_outlined, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('175 views', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Vehicle Specifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const _DetailRow(label: 'Make', value: 'Toyota'),
                  const _DetailRow(label: 'Model', value: 'Corolla Hybrid'),
                  const _DetailRow(label: 'Mileage', value: '45,000 km'),
                  const _DetailRow(label: 'Fuel Type', value: 'Hybrid / Petrol'),
                  const _DetailRow(label: 'Transmission', value: 'Automatic'),
                  const _DetailRow(label: 'Power', value: '184 HP'),
                  const _DetailRow(label: 'First Registration', value: 'March 2021'),
                  const _DetailRow(label: 'MOT Valid Until', value: 'March 2027'),
                  const SizedBox(height: 20),
                  const Text('Equipment & Features', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Exterior', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: const [
                      _CheckFeature('Parking Sensors'),
                      _CheckFeature('Alloy Wheels'),
                      _CheckFeature('LED Headlights'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Interior & Comfort', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: const [
                      _CheckFeature('Automatic Climate Control'),
                      _CheckFeature('Navigation System'),
                      _CheckFeature('Bluetooth & CarPlay'),
                      _CheckFeature('Heated Seats'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Color: Pearl White Metallic\n'
                    'Interior: Premium Black Fabric\n'
                    'Immaculate condition, serviced regularly at official dealership. Full service history.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF8CD867),
                        child: Text('M', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Marcelle T.', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            Text('Active since 2022 · 24 listings', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            side: const BorderSide(
                              color: Color(0xFF8CD867),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Follow',
                            style: TextStyle(
                              color: Color(0xFF8CD867),
                            ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181F1A),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            label: const Text('Send Message to Seller', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CD867),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// 4. REAL ESTATE / IMMOBILIEN PRODUCT DETAIL PROTOTYPE
// ============================================================================
class _PrototypeRealEstateDetail extends StatelessWidget {
  const _PrototypeRealEstateDetail();

  @override
  Widget build(BuildContext context) {
    return _OverlappingDetailScaffold(
      title: '3-Bedroom Apartment in Bonapriso',
      imageUrl: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80',
      imageCounter: '1 / 5',
      bottomAction: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181F1A),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            label: const Text('Contact Landlord', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CD867),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFF8CD867), size: 14),
            SizedBox(width: 4),
            Text('Douala, Bonapriso', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Modern 3-Bedroom Apartment with Balcony & Parking',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Text('350,000 FCFA', style: TextStyle(color: Color(0xFF8CD867), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text('/ month (+ utilities)', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('2 days ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.visibility_outlined, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('240 views', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Property Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const _DetailRow(label: 'Property Type', value: 'Apartment'),
        const _DetailRow(label: 'Rooms', value: '3 Rooms'),
        const _DetailRow(label: 'Living Area', value: '110 m²'),
        const _DetailRow(label: 'Floor', value: '2nd Floor'),
        const _DetailRow(label: 'Monthly Rent', value: '350,000 FCFA'),
        const _DetailRow(label: 'Deposit', value: '700,000 FCFA'),
        const _DetailRow(label: 'Available From', value: 'November 1, 2025'),
        const _DetailRow(label: 'Energy Rating', value: 'Class A (Eco-efficient)'),
        const SizedBox(height: 20),
        const Text('Amenities', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _CheckFeature('Balcony / Terrace'),
            _CheckFeature('Modern Kitchen'),
            _CheckFeature('Elevator'),
            _CheckFeature('Secure Parking'),
            _CheckFeature('Air Conditioning'),
            _CheckFeature('Backup Generator'),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'This bright and modern 3-bedroom apartment is located in prime Bonapriso. '
          'Featuring a spacious balcony, air conditioning in all rooms, and a standby generator. '
          'Secure parking space included in the rent.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}


// ============================================================================
// 5. HOME & GARDEN PRODUCT DETAIL PROTOTYPE
// ============================================================================
class _PrototypeHomeGardenDetail extends StatelessWidget {
  const _PrototypeHomeGardenDetail();

  @override
  Widget build(BuildContext context) {
    return _OverlappingDetailScaffold(
      title: 'Solid Wood Dining Table',
      imageUrl: 'https://images.unsplash.com/photo-1530018607912-eff2daa1bac4?w=800&q=80',
      imageCounter: '1 / 4',
      bottomAction: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181F1A),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            label: const Text('Send Message', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CD867),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFF8CD867), size: 14),
            SizedBox(width: 4),
            Text('Douala, Bastos', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Solid Oak Dining Table 200x100 cm',
          style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Text('180,000 FCFA', style: TextStyle(color: Color(0xFF8CD867), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(width: 12),
            Text('Pickup only', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('3 days ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.visibility_outlined, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('85 views', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const _DetailRow(label: 'Category', value: 'Furniture'),
        const _DetailRow(label: 'Type', value: 'Tables'),
        const _DetailRow(label: 'Material', value: 'Solid Oak Wood'),
        const _DetailRow(label: 'Condition', value: 'Like New'),
        const _DetailRow(label: 'Dimensions (LxWxH)', value: '200 x 100 x 76 cm'),
        const SizedBox(height: 20),
        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Gorgeous dining table crafted from solid oak with natural edges. '
          'Freshly treated and oiled. Selling due to relocation. '
          'Pickup in Douala.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}


// ============================================================================
// 6. FASHION & BEAUTY PRODUCT DETAIL PROTOTYPE
// ============================================================================
class _PrototypeFashionDetail extends StatelessWidget {
  const _PrototypeFashionDetail();

  @override
  Widget build(BuildContext context) {
    return _OverlappingDetailScaffold(
      title: 'Nike Air Jordan 1 Retro High',
      imageUrl: 'https://images.unsplash.com/photo-1552346154-21d32810aba3?w=800&q=80',
      imageCounter: '1 / 5',
      bottomAction: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181F1A),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text('Message', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.verified_user, color: Colors.black),
                label: const Text('Direct Buy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CD867),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFF8CD867), size: 14),
            SizedBox(width: 4),
            Text('Douala, Akwa', style: TextStyle(color: Color(0xFF8CD867), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Nike Air Jordan 1 Retro High OG - Size 9.5 - Brand New',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Text('85,000 FCFA', style: TextStyle(color: Color(0xFF8CD867), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(width: 12),
            Text('Shipping available (3,000 FCFA)', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('1 day ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.visibility_outlined, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text('150 views', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const _DetailRow(label: 'Brand', value: 'Nike'),
        const _DetailRow(label: 'Model', value: 'Air Jordan 1'),
        const _DetailRow(label: 'Size', value: 'US 9.5 / EU 43'),
        const _DetailRow(label: 'Color', value: 'Black / White / Red'),
        const _DetailRow(label: 'Condition', value: 'Brand New in Box (Deadstock)'),
        const SizedBox(height: 20),
        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Unworn Nike Air Jordan 1 Retro High in size 43 (US 9.5). '
          'Brand new condition in original box (OG All). '
          'Purchase receipt from authorized retailer included.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}

// ============================================================================
// SHARED HELPER WIDGETS
// ============================================================================
class _PayLogo extends StatelessWidget {
  final String label;
  final Color color;

  const _PayLogo({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: textStyle.copyWith(color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckFeature extends StatelessWidget {
  final String label;

  const _CheckFeature(this.label);

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.check, color: Color(0xFF8CD867), size: 16);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

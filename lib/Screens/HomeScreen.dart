import 'package:flutter/material.dart';

// Components
import '../Components/CategoryItem.dart';
import '../Components/ItemCard.dart';
import '../Components/ItemDetailScreen.dart';
import '../Components/SearchHeader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = "For You";
  String _searchQuery = "";

  final List<CategoryItem> _categories = [
    CategoryItem(label: "For You", icon: Icons.thumb_up_alt_outlined, isSelected: true),
    CategoryItem(label: "RealEstate", icon: Icons.home_outlined),
    CategoryItem(label: "Haus & Garten", icon: Icons.weekend_outlined),
    CategoryItem(label: "Auto & Rad", icon: Icons.directions_car_outlined),
    CategoryItem(label: "Mode", icon: Icons.checkroom_outlined),
    CategoryItem(label: "Elektronik", icon: Icons.devices_outlined),
    CategoryItem(label: "Familie", icon: Icons.child_friendly_outlined),
    CategoryItem(label: "Sport", icon: Icons.sports_basketball_outlined),
    CategoryItem(label: "Jobs", icon: Icons.work_outline),
    CategoryItem(label: "Verschenken", icon: Icons.card_giftcard_outlined),
  ];

  final List<Map<String, String>> _allGalleryItems = [
    {
      "category": "Auto & Rad",
      "imageUrl": "https://picsum.photos/300/300?random=1",
      "title": "2x Original BMW Z4 G29 M40i 800M...",
      "price": "820 €",
      "priceAddon": "",
    },
    {
      "category": "Auto & Rad",
      "imageUrl": "https://picsum.photos/300/300?random=2",
      "title": "Deutz Fahr 6135C mit Binderberger...",
      "price": "133.280 €",
      "priceAddon": "VB",
    },
    {
      "category": "RealEstate",
      "imageUrl": "https://picsum.photos/300/300?random=3",
      "title": "WSOP Main 2023 - Card...",
      "price": "249 €",
      "priceAddon": "",
    },
    {
      "category": "Mode",
      "imageUrl": "https://picsum.photos/300/300?random=4",
      "title": "Nike Air Jordan 4 Black",
      "price": "210 €",
      "priceAddon": "",
    },
  ];

  final List<Map<String, dynamic>> _recommendedItems = [
    {
      "category": "Familie",
      "imageUrl": "https://picsum.photos/300/300?random=11",
      "title": "Kinderwagen Buggy Grey",
      "price": "120 €",
      "isFavorite": false,
    },
    {
      "category": "Mode",
      "imageUrl": "https://picsum.photos/300/300?random=12",
      "title": "Nike Air Jordan 4 Black",
      "price": "210 €",
      "isFavorite": true,
    },
  ];

  void _onCategoryTapped(int index) {
    setState(() {
      _selectedCategory = _categories[index].label;
      for (int i = 0; i < _categories.length; i++) {
        _categories[i] = CategoryItem(
          label: _categories[i].label,
          icon: _categories[i].icon,
          isSelected: i == index,
        );
      }
    });
  }

  void _openItemDetail(String title, String price, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          title: title,
          price: price,
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGallery = _allGalleryItems.where((item) {
      final matchesCategory = _selectedCategory == "For You" || item["category"] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || item["title"]!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final filteredRecommended = _recommendedItems.where((item) {
      final matchesCategory = _selectedCategory == "For You" || item["category"] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || item["title"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Search Header
            SliverToBoxAdapter(
              child: SearchHeader(
                locationText: "Aalen (+25 km)",
                onSearchChanged: (query) => setState(() => _searchQuery = query),
                onNotificationTap: () {},
              ),
            ),

            // Category Bar
            SliverToBoxAdapter(
              child: CategoryBar(
                categories: _categories,
                onSelectCategory: _onCategoryTapped,
              ),
            ),

            // Banner Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    "https://picsum.photos/600/250?random=10",
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Galerie Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "Galerie ($_selectedCategory)",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Horizontal Gallery List
            SliverToBoxAdapter(
              child: SizedBox(
                height: 210,
                child: filteredGallery.isEmpty
                    ? Center(child: Text("Keine Artikel in '$_selectedCategory'", style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredGallery.length,
                  itemBuilder: (context, index) {
                    final item = filteredGallery[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ItemCard(
                        imageUrl: item["imageUrl"]!,
                        title: item["title"]!,
                        price: item["price"]!,
                        priceAddon: item["priceAddon"]!.isEmpty ? null : item["priceAddon"],
                        isCompact: true,
                        onTap: () => _openItemDetail(item["title"]!, item["price"]!, item["imageUrl"]!),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Grid Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
                child: Text("Für dich empfohlen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            // Vertical Grid Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final item = filteredRecommended[index];
                    return ItemCard(
                      imageUrl: item["imageUrl"],
                      title: item["title"],
                      price: item["price"],
                      isFavorite: item["isFavorite"] ?? false,
                      onTap: () => _openItemDetail(item["title"], item["price"], item["imageUrl"]),
                    );
                  },
                  childCount: filteredRecommended.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
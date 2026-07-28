import 'package:flutter/material.dart';
import '../Service/ChatRoomScreen.dart';
import '../Service/ChatService.dart';
import 'ItemCard.dart';

class ItemDetailScreen extends StatefulWidget {
  final String title;
  final String price;
  final String imageUrl;
  final List<String>? images; // Optional list for multi-image gallery

  const ItemDetailScreen({
    Key? key,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.images,
  }) : super(key: key);

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  bool _isFavorite = false;

  // List of images (defaults to widget.imageUrl + generated mock samples if empty)
  late List<String> _imageList;

  // Related shop items mock data
  final List<Map<String, String>> _relatedItems = [
    {
      "title": "4x Winterreifen BMW Z4 G29",
      "price": "650 €",
      "imageUrl": "https://picsum.photos/300/300?random=21",
    },
    {
      "title": "Original BMW M Performance Lenkrad",
      "price": "420 €",
      "imageUrl": "https://picsum.photos/300/300?random=22",
    },
    {
      "title": "Brembo Bremsanlage Vorn",
      "price": "890 €",
      "imageUrl": "https://picsum.photos/300/300?random=23",
    },
    {
      "title": "BMW M Auspuffanlage Klappe",
      "price": "1.100 €",
      "imageUrl": "https://picsum.photos/300/300?random=24",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Populate gallery slider list
    _imageList = widget.images ?? [
      widget.imageUrl,
      "https://picsum.photos/600/600?random=31",
      "https://picsum.photos/600/600?random=32",
      "https://picsum.photos/600/600?random=33",
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Image Gallery Header Slider with PageView
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.indigo,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isFavorite = !_isFavorite);
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Horizontal PageView for Multiple Images
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _imageList.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _imageList[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      );
                    },
                  ),

                  // Image Counter Indicator (e.g. "1/4")
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_currentImageIndex + 1}/${_imageList.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Item Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Tag
                  const Text(
                    "73434 Aalen",
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Price Bar
                  Row(
                    children: [
                      Text(
                        widget.price,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Nur Abholung",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Meta details
                  Row(
                    children: const [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text("Vor 11 Stunden", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(width: 16),
                      Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text("377 Aufrufe", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 32),

                  // Description
                  const Text("Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    "Verkaufe zwei originale BMW M Leichtmetallfelgen Styling 800 M für die Vorderachse, demontiert von meinem BMW Z4 M40i G29. Felgen befinden sich in einem hervorragenden Zustand ohne Bordsteinschäden.",
                    style: TextStyle(height: 1.4, color: Colors.black87, fontSize: 14),
                  ),
                  const Divider(height: 40),

                  // 3. Related / Other Shop Items Section Header
                  const Text(
                    "Ähnliche Angebote im Shop",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 4. Grid of Other Related Shop Items
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
                  final item = _relatedItems[index];
                  return ItemCard(
                    imageUrl: item["imageUrl"]!,
                    title: item["title"]!,
                    price: item["price"]!,
                    onTap: () {
                      // Navigate to another ItemDetailScreen when tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemDetailScreen(
                            title: item["title"]!,
                            price: item["price"]!,
                            imageUrl: item["imageUrl"]!,
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

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),

      // Floating Bottom Message Action Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 2,
            ),
            onPressed: () {
              // 1. Initialize or fetch existing conversation session
              final conversation = ChatService().startOrGetChat(
                itemTitle: widget.title,
                itemPrice: widget.price,
                itemImageUrl: widget.imageUrl,
                sellerName: 'Mambanda Seller', // Seller name
              );

              // 2. Open Chat Room
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatRoomScreen(conversation: conversation),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text(
              "Nachricht",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
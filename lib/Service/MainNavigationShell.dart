import 'package:flutter/material.dart';

// Screens imports
import '../DashBoards/CreateListingScreen.dart';
import '../Screens/AccountScreen.dart';
import '../Screens/ChatInboxScreen.dart';
import '../Screens/FavoritesScreen.dart';
import '../Screens/HomeScreen.dart';
         // Profile Tab

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentBottomIndex = 0;

  // List of tab views
  final List<Widget> _pages = const [
    HomeScreen(),          // Index 0: Search / Home Feed
    FavoritesScreen(),     // Index 1: Favorites
    SizedBox.shrink(),     // Index 2: Placeholder for Insert Modal Action
    ChatInboxScreen(),     // Index 3: Charts / Messaging
    AccountScreen(),       // Index 4: Account
  ];

  void _onTabTapped(int index) async {
    // Index 2 corresponds to "Insert" (+) action
    if (index == 2) {
      // Open Create Listing Screen as a Modal / Screen
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateListingScreen()),
      );
      return;
    }

    setState(() {
      _currentBottomIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentBottomIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: "Favorite",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 30, color: Colors.indigo),
            label: "Insert",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Account",
          ),
        ],
      ),
    );
  }
}
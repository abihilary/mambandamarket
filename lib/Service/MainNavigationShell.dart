import 'package:flutter/material.dart';

// Screens imports
import '../DashBoards/CreateListingScreen.dart';
import '../Screens/AccountScreen.dart';
import '../Screens/ChatInboxScreen.dart';
import '../Screens/FavoritesScreen.dart';
import '../Screens/HomeScreen.dart';
import '../l10n/l10n.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentBottomIndex = 0;

  // Placeholder flag for user plan status (Replace with actual user/auth state later)
  final bool _isFreePlan = true;

  // List of tab views
  final List<Widget> _pages = const [
    HomeScreen(),          // Index 0: Search / Home Feed
    FavoritesScreen(),     // Index 1: Favorites
    SizedBox.shrink(),     // Index 2: Placeholder for Insert Modal Action
    ChatInboxScreen(),     // Index 3: Charts / Messaging
    AccountScreen(),       // Index 4: Account
  ];

  void _onTabTapped(int index) async {
    // Index 2 corresponds to "Publish" (+) action
    if (index == 2) {
      if (_isFreePlan) {
        _showUpgradeDialog();
      } else {
        // Open Create Listing Screen as a Modal / Screen
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateListingScreen()),
        );
      }
      return;
    }

    setState(() {
      _currentBottomIndex = index;
    });
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upgrade Required'),
        content: const Text(
          'Posting new listings requires a premium plan. Would you like to upgrade your subscription now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
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
        // Selected/unselected colours come from bottomNavigationBarTheme so the
        // bar tracks the brand accent in both light and dark.
        type: BottomNavigationBarType.fixed,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: context.l10n.navSearch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border),
            label: context.l10n.navFavorites,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline,
                size: 30, color: Theme.of(context).colorScheme.primary),
            label: context.l10n.navPublish,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: context.l10n.navMessages,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: context.l10n.navAccount,
          ),
        ],
      ),
    );
  }
}
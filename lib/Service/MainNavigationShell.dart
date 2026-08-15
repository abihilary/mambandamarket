import 'package:flutter/material.dart';

// Screens imports
import '../DashBoards/CreateListingScreen.dart';
import '../api/auth_service.dart';
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

  /// Whether this account still has room to publish.
  ///
  /// This was a hardcoded `true` "replace with real state later", which meant
  /// the Publish tab answered "upgrade required" to everybody — a paying
  /// subscriber, a verified company, and a free user with all three of their
  /// listings still unused. The only way to reach the form was through a
  /// seller dashboard, so for anyone else the button in the middle of the tab
  /// bar simply did not work.
  ///
  /// `/me` already carries the quota, and Me.canPublish already interprets it
  /// (a null limit means unlimited). The server stays the authority — the
  /// create screen surfaces listing_limit_reached if the count moved
  /// underneath us — so this only decides whether to offer the form or the
  /// upgrade prompt.
  ///
  /// Defaults to letting them through when the profile has not loaded: a
  /// failed /me should not look like an expired subscription.
  bool get _canPublish => AuthService.instance.me.value?.canPublish ?? true;

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
      if (!_canPublish) {
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
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.upgradeRequiredTitle),
        content: Text(l10n.upgradeRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.upgradeCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/subscription');
            },
            child: Text(l10n.upgradeConfirm),
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
import 'dart:async';

import 'package:flutter/material.dart';

// Screens imports
import '../DashBoards/CreateListingScreen.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
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

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  int _currentBottomIndex = 0;

  /// Backstop behind the live subscription.
  ///
  /// Realtime is a socket, and sockets drop — on a train, on a lift, on a
  /// carrier that decides an idle connection has had long enough. This sweeps
  /// quietly in the background so a missed event costs a minute rather than
  /// lasting until somebody thinks to open the tab.
  static const Duration _sweepInterval = Duration(seconds: 45);
  Timer? _sweep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatRepository.instance.startLive();
    _startSweep();
  }

  @override
  void dispose() {
    _sweep?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ChatRepository.instance.stopLive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back from the background used to change nothing: the inbox was
      // as stale as the moment the app was put down. The socket is also very
      // likely to have been closed while away, so it is re-established here.
      ChatRepository.instance.startLive();
      _inboxKey.currentState?.reload();
      _startSweep();
    } else if (state == AppLifecycleState.paused) {
      // Nothing to poll for while nobody is looking. Push is what reaches a
      // closed app, and that is not built yet.
      _sweep?.cancel();
    }
  }

  void _startSweep() {
    _sweep?.cancel();
    _sweep = Timer.periodic(_sweepInterval, (_) => _quietRefresh());
  }

  /// Refresh without touching the screen's own loading state, so the inbox
  /// updates underneath the user instead of flashing a spinner at them.
  Future<void> _quietRefresh() async {
    try {
      await ChatRepository.instance.refresh();
    } catch (_) {
      // Offline, most likely. The next sweep tries again.
    }
  }

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

  /// How the Messages tab is told to look again.
  ///
  /// The IndexedStack below keeps every tab alive, so the inbox loads once
  /// when the app starts and then never again on its own. A conversation that
  /// began after launch stayed invisible: the seller hub counted it on the
  /// listing, and Messages still said there were none.
  final GlobalKey<ChatInboxScreenState> _inboxKey =
      GlobalKey<ChatInboxScreenState>();

  // List of tab views
  late final List<Widget> _pages = [
    const HomeScreen(),              // Index 0: Search / Home Feed
    const FavoritesScreen(),         // Index 1: Favorites
    const SizedBox.shrink(),         // Index 2: Placeholder for Insert Modal Action
    ChatInboxScreen(key: _inboxKey), // Index 3: Charts / Messaging
    const AccountScreen(),           // Index 4: Account
  ];

  void _onTabTapped(int index) async {
    // Index 2 corresponds to "Publish" (+) action
    if (index == 2) {
      if (!_canPublish) {
        _showUpgradeDialog();
      } else {
        // The result is the new listing, or null if the seller backed out.
        //
        // This used to be awaited and dropped. Both dashboards reload after
        // publishing, but the + in the tab bar is how most listings are
        // created, and from here nothing refreshed: the seller published an
        // item, landed back on a feed built at launch, and could not find it.
        // Restarting the app was the only way to see their own listing.
        final created = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const CreateListingScreen()),
        );
        if (created == null || !mounted) return;
        // The feed refetches itself off ListingsRepository.revision, which the
        // publish already bumped — so it is reloading before this runs. All
        // that is left is to show them the tab it lands on, rather than
        // leaving them on whatever one they pressed + from.
        setState(() => _currentBottomIndex = 0);
      }
      return;
    }

    // Opening Messages re-reads the inbox. Without this it keeps showing
    // whatever was true when the app was opened.
    if (index == 3) _inboxKey.currentState?.reload();

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
            // Unread count, so a message that arrives while you are on another
            // tab says so. Until now nothing in the bar changed at all.
            icon: ValueListenableBuilder<int>(
              valueListenable: ChatRepository.instance.totalUnread,
              builder: (context, unread, child) => Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: child,
              ),
              child: const Icon(Icons.chat_bubble_outline),
            ),
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
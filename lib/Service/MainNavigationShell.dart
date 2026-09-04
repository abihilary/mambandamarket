import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
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
import '../theme/app_tokens.dart';

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

  /// Open the create form.
  ///
  /// Was reached through tab index 2, which no longer exists as a tab: the
  /// deck puts Publish on a disc straddling the bar, so it is a docked FAB and
  /// this is what it calls. The quota gate is unchanged.
  Future<void> _openPublish() async {
    if (!_canPublish) {
      _showUpgradeDialog();
      return;
    }
    {
      {
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
    }
  }

  void _onTabTapped(int index) {
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
      // Content runs underneath the bar rather than stopping above it. Without
      // this there is nothing behind the glass to blur except the scaffold's
      // own background, and the effect costs a frame to render nothing. Every
      // scrollable in the tabs already carries 96px of bottom padding for the
      // publish button, which is also what keeps the last row reachable here.
      extendBody: true,
      body: IndexedStack(
        index: _currentBottomIndex,
        children: _pages,
      ),
      // The deck puts Publish on a lime disc straddling the bar rather than in
      // a fifth slot. BottomNavigationBar cannot cut a notch, so the bar is a
      // BottomAppBar with four hand-rolled tabs and a docked FAB between them.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _PublishButton(onPressed: _openPublish),
      bottomNavigationBar: Stack(
        children: [
          // The glass sits behind the bar rather than around it, so
          // BottomAppBar keeps doing its own layout — height, safe-area inset
          // and notch — and this only has to match the shape it draws.
          Positioned.fill(child: _GlassBarBackdrop()),
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 7,
            height: 68,
            padding: EdgeInsets.zero,
            // The colour moved to the backdrop above. Left opaque here it
            // would paint over the blur it is meant to be showing.
            color: Colors.transparent,
            elevation: 0,
            child: Row(
              children: [
                // Home, not Search. The magnifier was accurate while the feed
                // was the only place you could search from; now that search is
                // a screen of its own, a tab that opens the feed and calls
                // itself Search sends you to the wrong place twice — once for
                // the word and once for the glyph.
                _NavItem(
                  icon: Icons.home_outlined,
                  label: context.l10n.navHome,
                  selected: _currentBottomIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.favorite_border,
                  label: context.l10n.navFavorites,
                  selected: _currentBottomIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                // Room for the notch the FAB sits in.
                const Spacer(),
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: context.l10n.navMessages,
                  selected: _currentBottomIndex == 3,
                  onTap: () => _onTabTapped(3),
                  // Unread count, so a message that arrives while you are on
                  // another tab says so.
                  badgeListenable: ChatRepository.instance.totalUnread,
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: context.l10n.navAccount,
                  selected: _currentBottomIndex == 4,
                  onTap: () => _onTabTapped(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The blurred, tinted pane behind the tab bar.
///
/// Clipped to the same notched outline BottomAppBar draws, so the FAB still
/// cuts a hole in the bar instead of sitting on a rectangle. The shape comes
/// from `CircularNotchedRectangle` itself rather than a hand-rolled arc, which
/// is what keeps the two edges identical.
///
/// The tint and the hairline are painted along that same path: a `Border` on a
/// box would draw its top edge straight across the notch.
class _GlassBarBackdrop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipPath(
      clipper: const _NotchedBarClipper(),
      child: BackdropFilter(
        // Modest on purpose: a Gaussian blur costs in proportion to its sigma,
        // and this strip is redrawn on every frame of every scroll.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CustomPaint(
          painter: _NotchedBarPainter(
            fill: tokens.glassTint,
            stroke: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// The bar's outline, notch and all.
///
/// 28 is the default FloatingActionButton radius and 7 is the notchMargin set
/// on the BottomAppBar above; the guest circle is centred on the top edge,
/// which is where a centre-docked FAB sits.
Path _notchedBarPath(Size size) {
  const double fabRadius = 28;
  const double notchMargin = 7;
  final guest = Rect.fromCircle(
    center: Offset(size.width / 2, 0),
    radius: fabRadius + notchMargin,
  );
  return const CircularNotchedRectangle()
      .getOuterPath(Offset.zero & size, guest);
}

class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper();

  @override
  Path getClip(Size size) => _notchedBarPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NotchedBarPainter extends CustomPainter {
  final Color fill;
  final Color stroke;

  const _NotchedBarPainter({required this.fill, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedBarPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter old) =>
      old.fill != fill || old.stroke != stroke;
}
/// The lime disc in the middle of the bar.
///
/// Uses the brand tokens rather than `colorScheme.primary`: primary is `ink` in
/// the light theme, which would render this as a black button in a design whose
/// whole point is that it is lime. A fill can be lime on either ground because
/// what sits on it is near-black.
class _PublishButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PublishButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: tokens.accentFill,
      foregroundColor: tokens.onAccentFill,
      elevation: 2,
      shape: const CircleBorder(),
      tooltip: context.l10n.navPublish,
      child: const Icon(Icons.add, size: 30),
    );
  }
}

/// One tab in the bar.
///
/// Hand-rolled because BottomAppBar has no item model of its own. Colours come
/// from bottomNavigationBarTheme so the bar still tracks the accent in both
/// themes instead of hardcoding lime, which cannot be read on a light ground.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ValueListenable<int>? badgeListenable;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeListenable,
  });

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).bottomNavigationBarTheme;
    final color = selected ? bar.selectedItemColor : bar.unselectedItemColor;

    Widget glyph = Icon(icon, size: 24, color: color);
    final badge = badgeListenable;
    if (badge != null) {
      glyph = ValueListenableBuilder<int>(
        valueListenable: badge,
        builder: (context, unread, child) => Badge.count(
          count: unread,
          isLabelVisible: unread > 0,
          child: child,
        ),
        child: glyph,
      );
    }

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        containedInkWell: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

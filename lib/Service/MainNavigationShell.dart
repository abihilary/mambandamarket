import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

// Screens imports
import '../DashBoards/CreateListingScreen.dart';
import '../api/auth_service.dart';
import '../api/notification_repository.dart';
import '../api/repositories.dart';
import '../Screens/AccountScreen.dart';
import '../Screens/ChatInboxScreen.dart';
import '../Screens/FavoritesScreen.dart';
import '../Screens/HomeScreen.dart';
import '../Screens/MabandaDeliveryHomeScreen.dart';
import '../Screens/ShipmentsScreen.dart';
import '../Components/require_account.dart';
import '../Components/shipping_button.dart';
import '../api/shipping_repository.dart';
import '../l10n/l10n.dart';
import '../navigation.dart';
import '../web/install_hint.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

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
    // The button only exists when the server says the feature is open, so the
    // catalogue is fetched once at launch. It is cached on the device, so this
    // is a no-op on every launch after the first.
    ShippingRepository.instance.loadOptions().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    // A visitor browsing the web app without an account: no inbox, no
    // notifications, no Home card — each of those is an authenticated call
    // that would only come back 401.
    if (_guest) return;
    ChatRepository.instance.startLive();
    unawaited(NotificationRepository.instance.refreshUnread());
    unawaited(NotificationRepository.instance.refreshHomeCard());
    _startSweep();
    // A visitor who signed in from a listing goes back to it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await ReturnTo.consume();
      if (id != null && mounted) await openSharedListing(id);
    });
  }

  /// Signed out. Only reachable on the web build, where browsing is open;
  /// the phone app sends a signed-out launch to Welcome instead. Fixed for the
  /// life of the shell: signing in replaces it with a new one.
  final bool _guest = AuthService.instance.session == null;

  @override
  void dispose() {
    _sweep?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_guest) ChatRepository.instance.stopLive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_guest) return;
    if (state == AppLifecycleState.resumed) {
      // Coming back from the background used to change nothing: the inbox was
      // as stale as the moment the app was put down. The socket is also very
      // likely to have been closed while away, so it is re-established here.
      ChatRepository.instance.startLive();
      // Refresh the badge directly, not only through the inbox. The inbox's
      // reload is what repaints its list, but its State is null until that tab
      // has been built — so relying on it alone meant a resume could leave the
      // badge stuck on its pre-background value until the next 45s sweep.
      unawaited(ChatRepository.instance.refresh());
      unawaited(NotificationRepository.instance.refreshUnread());
      unawaited(NotificationRepository.instance.refreshHomeCard());
      // And ask again whether shipping is open. It is a kill switch, and one
      // that only answers at cold start is a switch that takes days to reach
      // somebody who never fully closes the app — which is most people.
      unawaited(
        ShippingRepository.instance.loadOptions().then((_) {
          if (mounted) setState(() {});
        }),
      );
      _inboxKey.currentState?.reload();
      _startSweep();
    } else if (state == AppLifecycleState.paused) {
      // Nothing to poll for while nobody is looking; push reaches a closed app.
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
      await NotificationRepository.instance.refreshUnread();
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
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  /// When the back button was last pressed on home, for the double-press exit.
  DateTime? _lastBackOnHome;

  late final List<Widget> _pages = [
    HomeScreen(key: _homeKey), // Index 0: Search / Home Feed
    _guest
        ? const _GuestTab(kind: _GuestTabKind.favorites)
        : const FavoritesScreen(), // Index 1: Favorites
    const SizedBox.shrink(), // Index 2: Placeholder for Insert Modal Action
    _guest
        ? const _GuestTab(kind: _GuestTabKind.messages)
        : ChatInboxScreen(key: _inboxKey), // Index 3: Charts / Messaging
    _guest
        ? const _GuestTab(kind: _GuestTabKind.account)
        : const AccountScreen(), // Index 4: Account
  ];

  /// The sidebar's four entries, as indices into [_pages]. Slot 2 is the
  /// publish placeholder, which the sidebar shows as a button instead.
  static const List<int> _railPages = [0, 1, 3, 4];

  /// Home and Favourites: the two places somebody is looking at things they
  /// might want shipped. Not Messages or Account, where it would just be
  /// furniture on top of somebody's private screens.
  bool get _showsShippingButton =>
      (_currentBottomIndex == 0 || _currentBottomIndex == 1) &&
      ShippingRepository.instance.enabled;

  /// Whether the button is still showing its label.
  bool _shipExtended = true;
  static const double _shipCollapseAt = 132;
  static const double _shipExpandAt = 104;

  /// Collapse to a disc once the feed is moving, and never swallow the
  /// notification: RefreshIndicator and both feeds are listening too.
  bool _onFeedScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final extended = _shipExtended
        ? n.metrics.pixels < _shipCollapseAt
        : n.metrics.pixels < _shipExpandAt;
    if (extended != _shipExtended) setState(() => _shipExtended = extended);
    return false;
  }

  Future<void> _openShippingRequest() async {
    if (!await requireAccount(context, context.l10n.shipSignInRequired)) {
      return;
    }
    if (!mounted) return;
    // Navigate to the new Mabanda Delivery Landing Page
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MabandaDeliveryHomeScreen()),
    );
  }

  /// Open the create form.
  ///
  /// Was reached through tab index 2, which no longer exists as a tab: the
  /// deck puts Publish on a disc straddling the bar, so it is a docked FAB and
  /// this is what it calls. The quota gate is unchanged.
  Future<void> _openPublish() async {
    if (!await requireAccount(context, context.l10n.sellSignInRequired)) {
      return;
    }
    if (!mounted) return;
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
    // Account: where the web build offers the iPhone install card, rather
    // than over the feed on arrival.
    if (index == 4) offerInstall();

    // Home, tapped while on home: top of the feed, reloaded.
    if (index == 0 && _currentBottomIndex == 0) {
      unawaited(_homeKey.currentState?.scrollToTopAndRefresh());
      return;
    }

    setState(() {
      _currentBottomIndex = index;
    });
  }

  /// The system back button. On any other tab it goes home; on home it takes
  /// two presses within two seconds to leave, so a slip does not close the app.
  void _onBack() {
    if (_currentBottomIndex != 0) {
      setState(() => _currentBottomIndex = 0);
      return;
    }
    // A browser tab is not closed by its back button, and "press again to
    // exit" that then does nothing reads as broken.
    if (kIsWeb) return;
    final now = DateTime.now();
    if (_lastBackOnHome != null &&
        now.difference(_lastBackOnHome!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackOnHome = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.backAgainToExit),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          // Above the bar. Not beside the sidebar, where the theme gives
          // snackbars a width, and a width and a margin cannot both be set.
          margin: context.isWideLayout
              ? null
              : const EdgeInsets.fromLTRB(16, 0, 16, 96),
        ),
      );
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

  /// The desktop layout: a sidebar where the bottom bar was, with Sell and
  /// Ship in it, and the tabs beside it.
  Widget _buildWide(BuildContext context) {
    final railIndex = _railPages.indexOf(_currentBottomIndex);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideRail(
            selected: railIndex < 0 ? 0 : railIndex,
            extended: context.isLargeLayout,
            guest: _guest,
            onSelect: (i) => _onTabTapped(_railPages[i]),
            onPublish: _openPublish,
            onShip: ShippingRepository.instance.enabled
                ? _openShippingRequest
                : null,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // No floating ship button here: the sidebar carries it, on
                // every tab, and a second one in the corner said it twice.
                IndexedStack(
                  index: _currentBottomIndex,
                  children: _pages,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWideLayout;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: wide ? _buildWide(context) : Scaffold(
        // Content runs underneath the bar rather than stopping above it. Without
        // this there is nothing behind the glass to blur except the scaffold's
        // own background, and the effect costs a frame to render nothing. Every
        // scrollable in the tabs already carries 96px of bottom padding for the
        // publish button, which is also what keeps the last row reachable here.
        extendBody: true,
        // StackFit.expand is load-bearing, not tidiness: a Stack is loose by
        // default for non-positioned children, and without it the IndexedStack
        // would shrink-wrap its tallest page instead of filling the body.
        body: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onFeedScroll,
              child: IndexedStack(index: _currentBottomIndex, children: _pages),
            ),
            // Browsing surfaces only. It sits above the bar rather than in the
            // Scaffold's FAB slot, which is taken — and a nested tab Scaffold's
            // endFloat measures from the physical screen bottom under
            // extendBody, so it would land inside the glass.
            if (_showsShippingButton)
              Positioned(
                right: 16,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 80,
                child: ShippingButton(
                  extended: _shipExtended,
                  onPressed: _openShippingRequest,
                ),
              ),
          ],
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
                    badgeListenable:
                        _guest ? null : ChatRepository.instance.totalUnread,
                  ),
                  _NavItem(
                    icon: _guest ? Icons.login_rounded : Icons.person_outline,
                    label: _guest ? context.l10n.signIn : context.l10n.navAccount,
                    selected: _currentBottomIndex == 4,
                    onTap: () => _onTabTapped(4),
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
  return const CircularNotchedRectangle().getOuterPath(
    Offset.zero & size,
    guest,
  );
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
        // The whole slot answers, not just the icon and label: the column
        // shrinks to ~42 px of a 68 px bar, and on a phone browser — where the
        // bar sits flush against Safari's toolbar zone — the misses were
        // reported as "the bottom nav doesn't respond".
        child: SizedBox.expand(
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
      ),
    );
  }
}

/// The desktop sidebar: the mark, the four tabs, then Sell and Ship.
///
/// Sell keeps the lime disc's identity — on a phone it is the disc in the bar,
/// here it is the one lime button in the column. Labels show from 1200px; below
/// that the rail is icons only, with tooltips.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.selected,
    required this.extended,
    required this.guest,
    required this.onSelect,
    required this.onPublish,
    required this.onShip,
  });

  final int selected;
  final bool extended;
  final bool guest;
  final ValueChanged<int> onSelect;
  final VoidCallback onPublish;
  final VoidCallback? onShip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);

    Widget messagesIcon(IconData icon) => guest
        ? Icon(icon)
        : ValueListenableBuilder<int>(
            valueListenable: ChatRepository.instance.totalUnread,
            builder: (context, unread, child) => Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: child,
            ),
            child: Icon(icon),
          );

    final sell = extended
        ? FloatingActionButton.extended(
            heroTag: null,
            onPressed: onPublish,
            backgroundColor: tokens.accentFill,
            foregroundColor: tokens.onAccentFill,
            elevation: 0,
            icon: const Icon(Icons.add),
            label: Text(l10n.navSell),
          )
        : FloatingActionButton(
            heroTag: null,
            onPressed: onPublish,
            backgroundColor: tokens.accentFill,
            foregroundColor: tokens.onAccentFill,
            elevation: 0,
            tooltip: l10n.navSell,
            child: const Icon(Icons.add),
          );

    final ship = onShip == null
        ? null
        : extended
            ? TextButton.icon(
                onPressed: onShip,
                icon: Icon(Icons.local_shipping_outlined,
                    color: tokens.accentInk),
                label: Text(l10n.shipFabLabel),
              )
            : IconButton(
                onPressed: onShip,
                tooltip: l10n.shipFabLabel,
                icon: Icon(Icons.local_shipping_outlined,
                    color: tokens.accentInk),
              );

    return NavigationRail(
      selectedIndex: selected,
      onDestinationSelected: onSelect,
      extended: extended,
      minExtendedWidth: 232,
      labelType: extended ? null : NavigationRailLabelType.none,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Column(
          crossAxisAlignment:
              extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/brand/mark.png', height: 36),
                if (extended) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Mambanda',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            sell,
          ],
        ),
      ),
      trailing: ship == null
          ? null
          : Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ship,
                ),
              ),
            ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: Text(l10n.navHome),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          label: Text(l10n.navFavorites),
        ),
        NavigationRailDestination(
          icon: messagesIcon(Icons.chat_bubble_outline),
          selectedIcon: messagesIcon(Icons.chat_bubble),
          label: Text(l10n.navMessages),
        ),
        NavigationRailDestination(
          icon: Icon(guest ? Icons.login_rounded : Icons.person_outline),
          selectedIcon: Icon(guest ? Icons.login_rounded : Icons.person),
          label: Text(guest ? l10n.signIn : l10n.navAccount),
        ),
      ],
    );
  }
}

enum _GuestTabKind { favorites, messages, account }

/// What a signed-out visitor sees on a tab that only makes sense with an
/// account: what it is for, and the two ways in.
class _GuestTab extends StatelessWidget {
  const _GuestTab({required this.kind});

  final _GuestTabKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final (icon, title, body) = switch (kind) {
      _GuestTabKind.favorites => (
          Icons.favorite_border,
          l10n.navFavorites,
          l10n.signInToSeeFavorites,
        ),
      _GuestTabKind.messages => (
          Icons.chat_bubble_outline,
          l10n.navMessages,
          l10n.signInToSeeMessages,
        ),
      _GuestTabKind.account => (
          Icons.person_outline,
          l10n.guestAccountTitle,
          l10n.guestAccountBody,
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              shellBottomClearance(context),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Breakpoints.auth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 48, color: tokens.accentInk),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/welcome'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentFill,
                      foregroundColor: tokens.onAccentFill,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(l10n.createAccount),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(l10n.logIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

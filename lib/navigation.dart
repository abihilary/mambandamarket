import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'Components/ItemDetailScreen.dart';
import 'Screens/PublicProfileScreen.dart';
import 'api/auth_service.dart';
import 'api/repositories.dart';
import 'api/share_links.dart';

/// The app's one Navigator, reachable without a BuildContext.
///
/// Most navigation starts from a widget and has a context to hand. Two things
/// do not: a password-recovery link, and a tapped push notification. Both
/// arrive from outside the widget tree entirely — the second can arrive before
/// there is a tree at all, when the notification is what launched the app —
/// so the key lives here rather than inside the root widget's State.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Keeps platform deep links out of the Navigator.
///
/// Returning from Google consent, or from a password-reset or email-confirmation
/// link, re-enters the app through `com.mabanda.mambandamarket://login-callback`.
/// Flutter hands every incoming link to the Navigator as a route push — and for
/// a `scheme://host` URL `uri.path` is *empty*, so WidgetsApp substitutes `'/'`
/// and calls `pushNamed('/')`. That is the splash route. A second SplashScreen
/// was therefore pushed on top of whatever was already on screen, and because
/// the splash finishes with pushReplacementNamed — which replaces only itself —
/// the sign-in screen underneath survived into the app:
///
///     [welcome]  →  [welcome, splash]  →  [welcome, home]
///
/// So the first back press out of the marketplace landed on Welcome, and the
/// next on Log in. Signing in appeared to work and then quietly left the door
/// it came through standing open behind it.
///
/// supabase_flutter consumes these links itself — it is listening for exactly
/// this callback to complete the session — so the Navigator has no business
/// seeing them. Returning true marks the link handled and stops the framework
/// offering it to WidgetsApp, which is the next observer in line.
///
/// Registered before runApp so it is ahead of WidgetsApp in the observer list:
/// the first observer to answer true wins. Nothing in the app navigates by URL,
/// so nothing legitimate is being swallowed — a real link-driven route would be
/// routed from here rather than by falling through.
class DeepLinkGuard with WidgetsBindingObserver {
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    // A shared listing is the one link that does have somewhere to go. Android
    // only hands it over once it has verified the domain against
    // .well-known/assetlinks.json, so by the time this runs the link is known
    // to be ours; the parser checks the shape again anyway, because the same
    // path also sees links that arrived by other routes.
    final uri = routeInformation.uri;
    final id = kIsWeb
        ? ShareLinks.listingIdFromPath(uri.path)
        : ShareLinks.listingIdFrom(uri);
    if (id != null) {
      unawaited(openSharedListing(id));
      return true;
    }
    // A shared shop: same checks, opens the seller's page.
    final shopId = kIsWeb
        ? ShareLinks.shopIdFromPath(uri.path)
        : ShareLinks.shopIdFrom(uri);
    if (shopId != null) {
      openSharedShop(shopId);
      return true;
    }
    // A category tile on the website: the feed, on that category.
    final category = kIsWeb
        ? ShareLinks.categorySlugFromPath(uri.path)
        : ShareLinks.categorySlugFrom(uri);
    if (category != null) {
      openCategory(category);
      return true;
    }
    // An invite: keep the code for sign-up, or claim it now.
    final invite = kIsWeb
        ? ShareLinks.inviteCodeFromPath(uri.path)
        : ShareLinks.inviteCodeFrom(uri);
    if (invite != null) {
      unawaited(acceptInviteCode(invite));
      return true;
    }
    // Everything else is an auth callback. Handled, and deliberately not
    // routed — see above.
    return true;
  }
}

/// The page's address as it was when the web app started.
///
/// Read in main(), before runApp: the first route Flutter puts up is the
/// splash, named '/', and with path URLs it writes that name straight into
/// the address bar — so by the time the splash asks, /l/<id> already reads /.
String? _webLaunchPath;

void captureLaunchAddress() {
  if (kIsWeb) _webLaunchPath = Uri.base.path;
}

/// The link that launched the app, if that is how it started.
///
/// DeepLinkGuard only sees links that arrive while the app is running. A cold
/// start is different: the URL is handed over as the *initial route* instead,
/// which is the path a splash screen is already on, so the guard never runs
/// and the tap ended on the home feed.
///
/// That is also the common case. Somebody tapping a listing in WhatsApp is
/// usually not already in the app — quite often they have just installed it
/// because of the link.
///
/// Called after the first frame: there is no Navigator to push onto before it.
///
/// On the web the launch link is the page's own address — app.mambandamarket.com/l/<id>
/// — and it is already ours, so only the path is checked.
Future<void> handleLaunchLink() async {
  final String? id;
  final String? shopId;
  final String? invite;
  final String? category;
  if (kIsWeb) {
    final path = _webLaunchPath ?? '';
    id = ShareLinks.listingIdFromPath(path);
    shopId = ShareLinks.shopIdFromPath(path);
    invite = ShareLinks.inviteCodeFromPath(path);
    category = ShareLinks.categorySlugFromPath(path);
  } else {
    final raw = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final uri = Uri.tryParse(raw);
    id = uri == null ? null : ShareLinks.listingIdFrom(uri);
    shopId = uri == null ? null : ShareLinks.shopIdFrom(uri);
    invite = uri == null ? null : ShareLinks.inviteCodeFrom(uri);
    category = uri == null ? null : ShareLinks.categorySlugFrom(uri);
  }
  if (id != null) return openSharedListing(id);
  if (shopId != null) return openSharedShop(shopId);
  if (invite != null) return acceptInviteCode(invite);
  if (category != null) openCategory(category);
}

/// A category the home feed should switch to, set by a /c/<slug> link. The
/// shell answers by showing the Home tab; the feed answers by selecting it as
/// soon as it knows the category (on a cold start the list is still loading),
/// then clears it. A slug the app does not know is dropped, leaving the feed
/// as it was.
final ValueNotifier<String?> requestedCategory = ValueNotifier<String?>(null);

/// Back to the home feed, on [slug].
void openCategory(String slug) {
  rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  requestedCategory.value = null; // the same slug twice still fires
  requestedCategory.value = slug;
}

/// An invite link was opened. The code is parked on the device first —
/// that alone makes it count: the sign-up form shows it, and every route
/// through onboarding (email, Google, a later launch) claims a parked code
/// once a profile exists. Someone already signed in claims it now; the server
/// refuses it if they were referred before, which is the right answer.
Future<void> acceptInviteCode(String code) async {
  final auth = AuthService.instance;
  await auth.stashReferralCode(code);
  if (auth.session != null) await auth.redeemPendingReferral();
}

/// Open a seller's shop that arrived as a link. The profile screen fetches
/// the shop itself and has its own error state with a retry, so there is
/// nothing to prefetch here and nothing to fail.
void openSharedShop(String userId) {
  rootNavigatorKey.currentState?.push(MaterialPageRoute(
    builder: (_) => PublicProfileScreen(userId: userId),
  ));
}

/// Open a listing that arrived as a link.
///
/// The link carries an id and nothing else, so the record is fetched over the
/// API rather than reconstructed from the URL — the same reason a tapped push
/// notification refetches its thread. What the sender saw and what the
/// recipient sees then come from the same place, and a price edited since the
/// link was sent shows the new price.
///
/// Never throws. A link to something deleted, or a tap while offline, should
/// leave somebody in the app rather than on an error screen.
/// Open the reset screen if this launch is the return leg of a password reset.
///
/// Called from the splash *after* its stack clear, for the same reason the
/// shared link and the update countdown are: `pushNamedAndRemoveUntil` with a
/// `(_) => false` predicate removes every route, so anything pushed before it
/// is gone. That is what made the link appear to log you in and then drop you
/// on the home screen — the reset screen was pushed, then wiped, within the
/// same launch.
Future<void> maybeResumePasswordReset() async {
  if (!await AuthService.consumePendingRecovery()) return;
  final flag = AuthService.instance.passwordRecoveryRequested;
  // Already true means the live event arrived and the listener has routed.
  if (flag.value) return;
  flag.value = true;
}

Future<void> openSharedListing(String id) async {
  try {
    // A copy saved on this device opens at once, and the screen fetches the
    // fresh one. Otherwise the fetch here is the screen's: it is told so, and
    // does not ask (and count a view) a second time.
    final saved = ListingsRepository.instance.savedDetail(id);
    final listing = saved ?? await ListingsRepository.instance.detail(id);
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(MaterialPageRoute(
      builder: (_) => ItemDetailScreen(
        title: listing.title,
        price: listing.displayPrice,
        imageUrl: listing.primaryImageUrl,
        images: listing.imageUrls,
        listingId: listing.id,
        listing: listing,
        detailPrefetched: saved == null,
      ),
    ));
  } catch (e) {
    debugPrint('[links] could not open listing $id ($e)');
  }
}

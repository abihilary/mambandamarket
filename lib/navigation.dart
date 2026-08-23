import 'package:flutter/material.dart';

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
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async => true;
}

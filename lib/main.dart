import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:mambandamarket/Components/ReferalScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/auth_service.dart';
import 'Components/update_gate.dart';
import 'api/config.dart';
import 'api/app_info.dart';
import 'api/push_service.dart';
import 'l10n/l10n.dart';
import 'navigation.dart';
import 'theme/app_theme.dart';
import 'theme/breakpoints.dart';
import 'theme/theme_controller.dart';

// Screens & Dashboards
import 'package:mambandamarket/DashBoards/CreateListingScreen.dart';
import 'package:mambandamarket/DashBoards/SellerDashboardScreen.dart';
import 'package:mambandamarket/Screens/BusinessOnboardingScreen.dart';
import 'package:mambandamarket/Screens/LoginScreen.dart';
import 'api/offline_cache.dart';
import 'DashBoards/BusinessDashboardScreen.dart';
import 'DashBoards/CompanyDashboardScreen.dart';
import 'Screens/AccountStatusScreen.dart';
import 'Screens/ForgotPasswordScreen.dart';
import 'Screens/IndividualSellerOnboardingScreen.dart';
import 'Screens/MyOrdersScreen.dart';
import 'Screens/NotificationsScreen.dart';
import 'Screens/InviteFriendsScreen.dart';
import 'Screens/WalletScreen.dart';
import 'Screens/ResetPasswordScreen.dart';
import 'Screens/RoleSelectionScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/SubscriptionScreen.dart';
import 'Screens/WelcomeScreen.dart';
import 'Service/MainNavigationShell.dart';

Future<void> main() async {
  // Clean addresses on the web build (app.mambandamarket.com/l/<id>, not
  // /#/l/<id>), so a shared listing link can be opened in the web app as-is.
  // vercel.json already rewrites every unknown path to index.html. A no-op on
  // Android.
  usePathUrlStrategy();
  captureLaunchAddress();
  WidgetsFlutterBinding.ensureInitialized();

  // Ahead of runApp so this observer precedes WidgetsApp's: an auth callback
  // arriving as a deep link must not be pushed onto the Navigator as a route.
  WidgetsBinding.instance.addObserver(DeepLinkGuard());

  // Saved answers for when there is no connection. Before anything reads.
  await OfflineCache.init();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Touched here so its auth listener exists before anything else can fire one.
  // It cannot be earlier — the listener needs the client Supabase.initialize
  // creates — which is exactly why a recovery link arriving in the launch URL
  // is already handled by then, and why AuthService.consumePendingRecovery
  // exists to pick that case up below.
  AuthService.instance;

  // Read once so the very first API request already says which build it is.
  await AppInfo.warm();

  await LocaleController.instance.load();
  await ThemeController.instance.load();

  // Brings up Firebase Messaging so a closed app can still be reached. A build
  // with no google-services.json simply reports push unavailable and carries
  // on, so this is not a launch-blocking dependency.
  // Not on the web build: there is no service worker for it, and Firebase's
  // scripts loading and failing cost every cold start a second or more.
  if (!kIsWeb) await PushService.instance.init();

  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatefulWidget {
  const MarketplaceApp({super.key});

  @override
  State<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends State<MarketplaceApp> {

  @override
  void initState() {
    super.initState();
    AuthService.instance.passwordRecoveryRequested
        .addListener(_onPasswordRecovery);
  }

  @override
  void dispose() {
    AuthService.instance.passwordRecoveryRequested
        .removeListener(_onPasswordRecovery);
    super.dispose();
  }

  void _onPasswordRecovery() {
    if (!AuthService.instance.passwordRecoveryRequested.value) return;
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, themeMode, _) => MaterialApp(
          navigatorKey: rootNavigatorKey,
          // Wraps every route, so an old build is stopped wherever it is —
          // including a screen opened from a shared link or a notification.
          // Defaults inert; see UpdateGate for why it fails open.
          //
          // On a desktop-width window snackbars are a 480px card instead of a
          // strip across the whole screen. Always wrapped, only the data
          // changes, so resizing across the breakpoint keeps every route's
          // state.
          builder: (context, child) {
            final theme = Theme.of(context);
            final wide =
                MediaQuery.sizeOf(context).width >= Breakpoints.wide;
            return Theme(
              data: wide
                  ? theme.copyWith(
                      snackBarTheme:
                          theme.snackBarTheme.copyWith(width: 480),
                    )
                  : theme,
              child: UpdateGate(child: child ?? const SizedBox.shrink()),
            );
          },
          title: 'Mambanda Market',
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          // Mouse and trackpad drag rails and carousels too, not only a finger.
          scrollBehavior: const AppScrollBehavior(),
          initialRoute: '/',
          // Always one splash, whatever the address. The default splits a path
          // like /l/<id> into '/', '/l', '/l/<id>' and pushes a route for
          // each — three splash screens racing to replace themselves. The
          // splash reads the launch address itself (handleLaunchLink).
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: const RouteSettings(name: '/'),
            ),
          ],
          onGenerateRoute: (settings) {
            // Parse the incoming URI to extract path without query parameters
            final uri = Uri.parse(settings.name ?? '/');

            Widget builder;
            switch (uri.path) {
              case '/':
                builder = const SplashScreen();
                break;
              case '/welcome':
                builder = const WelcomeScreen();
                break;
              case '/role-selection':
                builder = const RoleSelectionScreen();
                break;
              case '/account-status':
                builder = const AccountStatusScreen();
                break;
              case '/home':
                builder = const MainNavigationShell();
                break;
              case '/login':
                builder = const LoginScreen();
                break;
              case '/forgot-password':
                builder = const ForgotPasswordScreen();
                break;
              case '/reset-password':
                builder = const ResetPasswordScreen();
                break;
              case '/bussiness':
                builder = BusinessOnboardingScreen();
                break;
              case '/create-listing':
                builder = const CreateListingScreen();
                break;
              case '/business-dashboard':
                builder = BusinessDashboardScreen();
                break;
              case '/seller-dashboard':
                builder = SellerDashboardScreen();
                break;
              case '/referral':
                // The step is a detour, so whoever pushes it says where to go
                // afterwards. Hardcoding /subscription sent free buyers to the
                // seller paywall the moment they skipped it.
                builder = ReferralScreen(
                  nextRoute: settings.arguments as String? ?? '/home',
                );
                break;
              case '/my-orders':
                builder = const MyOrdersScreen();
                break;
              case '/notifications':
                builder = const NotificationsScreen();
                break;
              case '/invite':
                builder = const InviteFriendsScreen();
                break;
              case '/wallet':
                builder = const WalletScreen();
                break;
              case '/company-dashboard':
                builder = const CompanyDashboardScreen();
                break;
              case '/seller-onboard':
                builder = IndividualSellerOnboardingScreen();
                break;
              case '/subscription':
                builder = SubscriptionScreen(
                  roleType:
                  AuthService.instance.me.value?.profile?.isBusiness == true
                      ? 'business'
                      : 'buyer_seller',
                );
                break;
              default:
                builder = const SplashScreen();
            }

            return MaterialPageRoute(
              builder: (context) => builder,
              settings: settings,
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:mambandamarket/Components/ReferalScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/auth_service.dart';
import 'api/config.dart';
import 'l10n/l10n.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

// Screens & Dashboards
import 'package:mambandamarket/DashBoards/CreateListingScreen.dart';
import 'package:mambandamarket/DashBoards/SellerDashboardScreen.dart';
import 'package:mambandamarket/Screens/BusinessOnboardingScreen.dart';
import 'package:mambandamarket/Screens/LoginScreen.dart';
import 'DashBoards/BusinessDashboardScreen.dart';
import 'DashBoards/CompanyDashboardScreen.dart';
import 'Screens/AccountStatusScreen.dart';
import 'Screens/ForgotPasswordScreen.dart';
import 'Screens/IndividualSellerOnboardingScreen.dart';
import 'Screens/MyOrdersScreen.dart';
import 'Screens/InviteFriendsScreen.dart';
import 'Screens/ResetPasswordScreen.dart';
import 'Screens/RoleSelectionScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/SubscriptionScreen.dart';
import 'Screens/WelcomeScreen.dart';
import 'Service/MainNavigationShell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  await LocaleController.instance.load();
  await ThemeController.instance.load();

  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatefulWidget {
  const MarketplaceApp({super.key});

  @override
  State<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends State<MarketplaceApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

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
    _navigatorKey.currentState?.push(
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
          navigatorKey: _navigatorKey,
          title: 'Mambanda Market',
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          initialRoute: '/',
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
              case '/invite':
                builder = const InviteFriendsScreen();
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
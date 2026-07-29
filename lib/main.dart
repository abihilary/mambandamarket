import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/auth_service.dart';
import 'api/config.dart';
import 'l10n/l10n.dart';

// Navigation Shell


// Screens & Dashboards
import 'package:mambandamarket/DashBoards/CreateListingScreen.dart';
import 'package:mambandamarket/DashBoards/SellerDashboardScreen.dart';
import 'package:mambandamarket/Screens/BusinessOnboardingScreen.dart';
import 'package:mambandamarket/Screens/LoginScreen.dart';
import 'DashBoards/BusinessDashboardScreen.dart';
import 'Screens/ForgotPasswordScreen.dart';
import 'Screens/IndividualSellerOnboardingScreen.dart';
import 'Screens/ResetPasswordScreen.dart';
import 'Screens/RoleSelectionScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/SubscriptionScreen.dart';
import 'Screens/WelcomeScreen.dart';
import 'Service/MainNavigationShell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase issues and persists the auth session; the Core API trusts the JWT
  // it mints. Only the publishable key ships in the client.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Restore the saved language before the first frame so the UI never flashes
  // in the wrong language.
  await LocaleController.instance.load();

  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatefulWidget {
  const MarketplaceApp({super.key});

  @override
  State<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends State<MarketplaceApp> {
  /// Lets us navigate in response to auth events that arrive from outside the
  /// widget tree (a password-recovery deep link can land on any screen).
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
    // The recovery session only permits setting a new password, so send the
    // user there rather than into the app.
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes so every screen picks up
    // the new locale immediately.
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, locale, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Mambanda Market',
        debugShowCheckedModeBanner: false,
        // null → Flutter falls back to the device language, then to English.
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          useMaterial3: true,
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/home': (context) => const MainNavigationShell(), // Updated to MainNavigationShell
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/bussiness': (context) => BusinessOnboardingScreen(),
        '/create-listing': (context) => const CreateListingScreen(),
        '/business-dashboard': (context) => BusinessDashboardScreen(),
        '/seller-dashboard': (context) => SellerDashboardScreen(),
        '/seller-onboard': (context) => IndividualSellerOnboardingScreen(),
        // Tier pricing differs for business vs. individual sellers, so pick the
        // plan set from the signed-in profile's role.
        '/subscription': (context) => SubscriptionScreen(
              roleType:
                  AuthService.instance.me.value?.profile?.isBusiness == true
                      ? 'business'
                      : 'buyer_seller',
            ),
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Navigation Shell


// Screens & Dashboards
import 'package:mambandamarket/DashBoards/CreateListingScreen.dart';
import 'package:mambandamarket/DashBoards/SellerDashboardScreen.dart';
import 'package:mambandamarket/Screens/BusinessOnboardingScreen.dart' hide BusinessDashboardScreen;
import 'package:mambandamarket/Screens/LoginScreen.dart';
import 'DashBoards/BusinessDashboardScreen.dart';
import 'Screens/IndividualSellerOnboardingScreen.dart';
import 'Screens/RoleSelectionScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/WelcomeScreen.dart';
import 'Service/MainNavigationShell.dart';

void main() {
  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketplace',
      debugShowCheckedModeBanner: false,
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
        '/bussiness': (context) => BusinessOnboardingScreen(),
        '/create-listing': (context) => const CreateListingScreen(),
        '/business-dashboard': (context) => BusinessDashboardScreen(),
        '/seller-dashboard': (context) => SellerDashboardScreen(),
        '/seller-onboard': (context) => IndividualSellerOnboardingScreen(),
      },
    );
  }
}
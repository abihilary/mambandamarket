import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/repositories.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    final auth = AuthService.instance;

    // Supabase restores any persisted session during initialize(); warm the
    // profile and saved items so the first screen renders with real data.
    if (auth.session != null) {
      try {
        await Future.wait([
          auth.refreshMe(),
          FavoritesRepository.instance.refresh(),
        ]);
      } catch (_) {
        // Offline or an expired token — fall through to the signed-out flow
        // rather than blocking startup.
      }
    }

    // Keep the brand moment visible briefly even when startup is instant.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      auth.session != null ? '/home' : '/welcome',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mambanda Market',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buy, Sell & Connect',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
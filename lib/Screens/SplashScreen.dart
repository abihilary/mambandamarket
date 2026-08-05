import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';

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

    // A session with no profile row means onboarding never finished (e.g. a
    // Google sign-in that was abandoned before choosing an account type), so
    // the user must be sent back to role selection rather than into the app.
    var profileMissing = false;

    // Supabase restores any persisted session during initialize(); warm the
    // profile and saved items so the first screen renders with real data.
    if (auth.session != null) {
      try {
        final results = await Future.wait([
          auth.refreshMe(),
          FavoritesRepository.instance.refresh(),
        ]);
        profileMissing = (results[0] as Me?)?.profile == null;
      } catch (_) {
        // Offline or an expired token — don't assume onboarding is incomplete;
        // fall through to /home (or the signed-out flow) rather than blocking.
      }
    }

    // Keep the brand moment visible briefly even when startup is instant.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final target = auth.session == null
        ? '/welcome'
        : auth.isAccountRestricted
            ? '/account-status'
            : (profileMissing ? '/role-selection' : '/home');
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    // The splash is a full-bleed brand plate, so everything on it is keyed to
    // onPrimary — the lime ground in dark mode cannot carry white.
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.onPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 64,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Mambanda Market',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.splashTagline,
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
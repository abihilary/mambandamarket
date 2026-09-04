import 'dart:async';

import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../Components/update_gate.dart';
import '../api/push_service.dart';
import '../navigation.dart';
import '../api/models.dart';
import '../api/location_service.dart';
import '../api/remote_config.dart';
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

    // Before anything decides what to show: how sign-up behaves and what a new
    // account may do are the server's call, not the build's. Falls back to the
    // cache and then to defaults, so this never blocks the launch.
    await RemoteConfig.instance.load();

    // Reads a cached coordinate off disk — it never touches the platform and
    // never prompts, so it costs nothing for the majority who have not granted
    // location. It is loaded here so the feed can read a position
    // synchronously on its very first build.
    await LocationService.instance.load();

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
        // A code entered at sign-up can only be claimed once a session exists,
        // which for the email-confirmation path is here, not there.
        await auth.redeemPendingReferral();
      } catch (_) {
        // Offline or an expired token — don't assume onboarding is incomplete;
        // fall through to /home (or the signed-out flow) rather than blocking.
      }
    }

    // Keep the brand moment visible briefly even when startup is instant.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // A session with no profile used to mean "send them to pick a role". With
    // the question switched off there is nothing to pick, so the default role
    // is applied and they carry on — otherwise they would be marooned on a
    // screen the flow is meant to have removed.
    if (profileMissing && !RemoteConfig.instance.roleSelectionEnabled) {
      try {
        await auth.syncProfile(role: RemoteConfig.instance.defaultSignupRole);
        await auth.refreshMe();
        profileMissing = false;
      } catch (_) {
        // Offline: leave it; the next launch or /me repairs it.
      }
    }

    final target = auth.session == null
        ? '/welcome'
        : auth.isAccountRestricted
            ? '/account-status'
            : (profileMissing ? '/role-selection' : '/home');
    // Clears the stack rather than replacing just this screen. The splash is
    // a gate: whatever it decides becomes the app's root, and nothing that was
    // on screen before it should be reachable by pressing back afterwards. On
    // a normal launch there is nothing underneath and this is identical to a
    // replace; it matters when the splash was reached any other way.
    Navigator.pushNamedAndRemoveUntil(context, target, (_) => false);

    // Only now open whatever launched the app — a shared listing link, or a
    // tapped notification. Both used to be opened from a post-frame callback
    // in main(), which put them on screen *before* this line ran and the
    // clear above then wiped them: tapping a shared listing on a phone where
    // the app was not already running landed on the home feed, which is the
    // most common way anyone receives one.
    //
    // Ordering, not timing: the splash decides the app's root, and these open
    // on top of it, so backing out of a shared listing leaves you in the app
    // rather than closing it.
    unawaited(handleLaunchLink());
    // Same ordering reason: the countdown is a route, and the clear above
    // would remove it.
    unawaited(maybeWarnAboutUpdate());
    unawaited(PushService.instance.handleLaunchNotification());
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
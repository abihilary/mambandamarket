import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../Components/ReferalScreen.dart';
import '../api/remote_config.dart';
import 'SignUpScreen.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Google sign-in finishes outside this screen (the user returns via the
    // deep link). Wait for AuthService to fully resolve the session before
    // routing: brand-new social accounts still need to pick an account type.
    AuthService.instance.signInResolved.addListener(_onSignInResolved);
  }

  @override
  void dispose() {
    AuthService.instance.signInResolved.removeListener(_onSignInResolved);
    super.dispose();
  }

  void _onSignInResolved() {
    // Schedule navigation after the frame completes to prevent build-phase crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = AuthService.instance;
      if (auth.session == null) return;

      // Two screens listen for this — whichever the user is standing on, plus
      // the one underneath. Without this they both route: Login pushes
      // synchronously, Welcome's post-frame callback then runs and replaces it,
      // and the referral step vanishes a frame after appearing. Only the screen
      // actually on top gets to decide where to go next.
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

      // A brand-new social account. The referral prompt used to be pushed by
      // the account-type screen; with that screen skipped this is the only
      // place left that knows this sign-in created the account, so offering it
      // here is what stops Google users quietly losing the ability to credit
      // whoever invited them. One-shot — cleared as it is consumed.
      if (auth.justSignedUpSocially) {
        auth.justSignedUpSocially = false;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ReferralScreen(nextRoute: '/home'),
          ),
          (_) => false,
        );
        return;
      }

      final String targetRoute;
      if (auth.isAccountRestricted) {
        targetRoute = '/account-status';
      } else if (auth.needsRoleSelection.value) {
        targetRoute = '/role-selection';
      } else if (auth.pendingSubscriptionRole != null) {
        auth.pendingSubscriptionRole = null;
        targetRoute = '/subscription';
      } else {
        targetRoute = '/home';
      }

      // The referral step deliberately does NOT live here. Asking before role
      // selection means asking before the profile row exists, and the server
      // refuses a code it has nothing to attach to; it also skips the role
      // step entirely. RoleSelectionScreen asks instead, once there is a
      // profile to attribute — and it only asks a genuinely new account, so
      // returning users are not nagged on every sign-in.
      Navigator.pushNamedAndRemoveUntil(context, targetRoute, (_) => false);
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final l10n = context.l10n;
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.googleSignInFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tokens = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Hero Icon / Graphic Area
              //
              // A lime disc rather than a bare lime glyph: on a light ground a
              // 100px lime icon on white is 1.4:1 — technically drawn, not
              // actually visible. The wash carries the brand and the glyph
              // stays ink.
              Center(
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: tokens.iconTile,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: tokens.accentInk,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),

              // Primary action. The deck leads on Create Account, and it is
              // also the honest ordering: Google is one way in, signing up is
              // the one everybody has.
              ElevatedButton(
                onPressed: () {
                  // Straight to the form when we are not asking what kind of
                  // account this is. The role still travels with the sign-up;
                  // it is chosen for them rather than by them.
                  final cfg = RemoteConfig.instance;
                  if (cfg.roleSelectionEnabled) {
                    Navigator.pushNamed(context, '/role-selection');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SignUpScreen(role: cfg.defaultSignupRole),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accentFill,
                  foregroundColor: tokens.onAccentFill,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.createAccount,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Google Sign-In
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.dividerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                label: Text(
                  l10n.continueWithGoogle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Existing Account Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.alreadyHaveAccount,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: Text(
                      l10n.logIn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
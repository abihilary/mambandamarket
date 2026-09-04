import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../Components/ReferalScreen.dart';
import '../api/remote_config.dart';
import 'SignUpScreen.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
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
              const SizedBox(height: 12),
              // The hero from screen 01 of the deck: the wordmark surrounded
              // by floating stock — headphones, a controller, a handbag,
              // trainers, a sofa, a phone, a tyre — on the lime-flecked dark
              // texture. It is the designer's own artwork rather than an
              // approximation of it, and it is the thing that makes the first
              // screen say "marketplace"; the bag glyph that used to sit here
              // said "an app".
              //
              // Always on its dark ground, in both themes. The art is dark by
              // construction, and the alternative — a light variant that does
              // not exist — would mean inventing one.
              // Expanded rather than a fixed height or a fixed ratio: the art
              // is 832x1440, which at full width would be 1.7 screens tall on
              // a phone. This gives it whatever is left after the copy and the
              // buttons have taken theirs, so it grows on a tall device and
              // shrinks on a short one instead of overflowing.
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.darkGround,
                    child: Image.asset(
                      'assets/brand/onboarding_hero.png',
                      // Centre-cropped, so the wordmark survives every shape of
                      // box; it is the products at the edges that give way
                      // first on a short screen.
                      fit: BoxFit.cover,
                      // A missing asset must not take the sign-in screen down
                      // with it: without this the whole route throws and the
                      // app has no way in at all.
                      errorBuilder: (context, error, stack) => const SizedBox(),
                    ),
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
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

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
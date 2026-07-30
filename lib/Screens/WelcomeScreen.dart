import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../l10n/l10n.dart';

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
    if (!mounted) return;
    final auth = AuthService.instance;
    if (auth.session == null) return;
    final String route;
    if (auth.isAccountRestricted) {
      route = '/account-status';
    } else if (auth.needsRoleSelection.value) {
      route = '/role-selection';
    } else {
      route = '/home';
    }
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Hero Icon / Graphic Area
              Icon(
                Icons.shopping_bag_outlined,
                size: 100,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const Spacer(),

              // Primary Action: Google Sign-In
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                label: Text(
                  l10n.continueWithGoogle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Email Sign Up
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/role-selection');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
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
              const SizedBox(height: 16),

              // Existing Account Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.alreadyHaveAccount,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                      // Login modal / screen
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
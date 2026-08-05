import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/auth_service.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Create an account with email + password.
///
/// Handles both Supabase configurations:
///  - confirmations OFF → a session comes back immediately and we go straight
///    into the app (running `/auth/sync` so the profile row exists);
///  - confirmations ON  → no session yet, so we show a "check your inbox"
///    state instead of pretending the user is signed in.
class SignUpScreen extends StatefulWidget {
  /// Role chosen on the previous screen: buyer | individual_seller | business.
  final String role;

  const SignUpScreen({super.key, this.role = 'buyer'});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _awaitingConfirmation = false;
  bool _isResending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _handleResend() async {
    if (_isResending) return;
    final l10n = context.l10n;
    setState(() => _isResending = true);
    try {
      await AuthService.instance.resendConfirmation(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.confirmationResent),
          backgroundColor: AppColors.success,
        ),
      );
    } on AuthException catch (e) {
      _showError(e.message.toLowerCase().contains('rate limit')
          ? l10n.resendRateLimited
          : e.message);
    } catch (_) {
      _showError(l10n.sendFailed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    final l10n = context.l10n;
    setState(() => _isLoading = true);

    try {
      final auth = AuthService.instance;
      await auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        role: widget.role,
      );

      if (!mounted) return;

      if (auth.session != null) {
        // Confirmations disabled ⇒ signed in immediately. Routing (home, or the
        // subscription step for seller/business) is handled by the sign-in
        // resolver on the Welcome/Login screen beneath this one, so we don't
        // navigate here.
      } else {
        // Email confirmation required before the account can be used.
        setState(() => _awaitingConfirmation = true);
      }
    } on AuthException catch (e) {
      // Supabase's built-in SMTP is heavily rate limited; say so plainly
      // instead of surfacing a raw error.
      final msg = e.message.toLowerCase().contains('rate limit')
          ? l10n.signUpRateLimited
          : e.message;
      _showError(msg);
    } catch (_) {
      _showError(l10n.signUpFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (_awaitingConfirmation) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(l10n.confirmEmailTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                l10n.confirmEmailBody(_emailController.text.trim()),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 24),
              // Without this, a lost or rate-limited confirmation email leaves
              // the user with no way forward except registering again.
              OutlinedButton.icon(
                onPressed: _isResending ? null : _handleResend,
                icon: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(_isResending ? l10n.sending : l10n.resendEmail),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.goToLogin,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signUpTitle), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.storefront,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.joinMambanda,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.fullName,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().length < 2
                      ? l10n.enterName
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      val == null || !val.contains('@') || !val.contains('.')
                          ? l10n.invalidEmail
                          : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    helperText: l10n.passwordMin8,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.length < 8
                      ? l10n.passwordMin8
                      : null,
                ),
                const SizedBox(height: 28),


                // Obligatory Referral Code Field
                TextFormField(
                  controller: _referralController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Referral Code *',
                    hintText: 'Enter your referral code',
                    prefixIcon: const Icon(Icons.card_giftcard_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),

                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary),
                        )
                      : Text(l10n.createAccount,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccount),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: Text(l10n.signIn,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

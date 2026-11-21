import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/breakpoints.dart';

/// Asks a new user for the code of whoever invited them.
///
/// This goes through the API, not straight to Supabase. `profiles` lets a user
/// update their own row, so a client-side write would let the person being
/// referred name any referrer they liked — including themselves. The server
/// validates the code, refuses self-referral, and sets the attribution once.
class ReferralScreen extends StatefulWidget {
  /// Where to go once the step is done or skipped. Null when it is opened
  /// later from Invite friends: it then pops back, with `true` once a code was
  /// accepted.
  final String? nextRoute;

  const ReferralScreen({super.key, required this.nextRoute});

  /// Opened from inside the app rather than as a step of onboarding.
  bool get isDetour => nextRoute == null;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _referralController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// A code parked from an invite link (/r/<code>) fills the box, so nobody who
  /// arrived with one has to type it — the sign-up form already did this, the
  /// Google route did not.
  Future<void> _prefill() async {
    final parked = await AuthService.instance.pendingReferralCode();
    if (!mounted || parked == null || _referralController.text.isNotEmpty) return;
    _referralController.text = parked;
  }

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  void _proceedToNext({bool claimed = false}) {
    if (!mounted) return;
    final next = widget.nextRoute;
    if (next == null) {
      Navigator.pop(context, claimed);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
  }

  Future<void> _handleSubmit() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) {
      _proceedToNext();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ReferralsRepository.instance.apply(code);
      await AuthService.instance.clearPendingReferral();
      _proceedToNext(claimed: true);
    } on ApiException catch (e) {
      // The profile row has not caught up with the session yet. That is the one
      // refusal worth retrying, so park the code and move on rather than
      // blocking onboarding on a race the user cannot see or fix.
      if (e.code == 'no_profile') {
        await AuthService.instance.stashReferralCode(code);
        _proceedToNext();
        return;
      }
      // A wrong code is worth saying out loud — silently moving on would leave
      // the person who invited them uncredited with nobody any the wiser.
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      // Offline or the server is unhappy: the code is kept for the next launch
      // rather than blocking someone from entering the app over it.
      await AuthService.instance.stashReferralCode(code);
      _proceedToNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.referralTitle),
        automaticallyImplyLeading: widget.isDetour,
        elevation: 0,
        actions: [
          if (!widget.isDetour)
          TextButton(
            onPressed: _isLoading ? null : _proceedToNext,
            child: Text(l10n.referralSkip),
          ),
        ],
      ),
      body: ContentFrame(
        maxWidth: Breakpoints.form,
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.card_giftcard_outlined,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.referralHeading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isDetour ? l10n.referralBodyLater : l10n.referralBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.referralCodeOptional,
                  hintText: l10n.referralCodeHint,
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
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
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        l10n.referralContinue,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              if (!widget.isDetour) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _proceedToNext,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.referralSkipForNow),
              ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

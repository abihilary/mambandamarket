import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/models.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Shown after sign-in when the account is blocked or suspended. A restricted
/// account keeps a valid session (so it can be told *why*), but the app never
/// lets it past this screen — the API also rejects any write server-side.
class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  bool _checking = false;
  bool _signingOut = false;

  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = context.l10n;
    try {
      await AuthService.instance.refreshMe();
    } catch (_) {
      // Ignore — we re-read the (possibly unchanged) status below.
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (!AuthService.instance.isAccountRestricted) {
      // Suspension lifted (or expired) — back into the app.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moderationStillRestricted)),
      );
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Fall through — routing away is what matters.
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
  }

  String? _formatUntil(BuildContext context, DateTime? until) {
    if (until == null) return null;
    final ml = MaterialLocalizations.of(context);
    final local = until.toLocal();
    return '${ml.formatFullDate(local)} · '
        '${ml.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Me?>(
          valueListenable: AuthService.instance.me,
          builder: (context, me, _) {
            final mod = me?.moderation ?? const Moderation();
            final blocked = mod.isBlocked;
            // Semantic tokens: these read the same way on a light or dark
            // ground, which a Material swatch shade would not.
            final color = blocked ? AppColors.danger : AppColors.warning;
            final icon = blocked ? Icons.block : Icons.pause_circle_outline;
            final title =
                blocked ? l10n.blockedTitle : l10n.suspendedTitle;
            final body = mod.reason ??
                (blocked ? l10n.blockedBodyDefault : l10n.suspendedBodyDefault);
            final untilStr =
                blocked ? null : _formatUntil(context, mod.suspendedUntil);

            return Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 88, color: color),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // The admin's message (or a default). This is exactly what was
                  // written when the account was suspended/blocked.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                  if (untilStr != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.suspendedUntil(untilStr),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (!blocked) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.suspendedIndefinite,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    l10n.moderationContactSupport,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // Suspended accounts can re-check (in case it was lifted or
                  // has expired). Blocked accounts only get a way out.
                  if (!blocked)
                    ElevatedButton.icon(
                      onPressed: _checking ? null : _checkAgain,
                      icon: _checking
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.ink))
                          : const Icon(Icons.refresh),
                      label: Text(l10n.moderationCheckAgain),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        // The fill here is always the amber warning token, and
                        // amber cannot carry white in either theme.
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  if (!blocked) const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _signingOut ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.moderationSignOut),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

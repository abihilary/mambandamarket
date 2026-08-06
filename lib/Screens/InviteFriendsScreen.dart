import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// The other half of referrals: the code you give out, and what it has earned.
///
/// Without this screen the whole feature is unusable — a code can be typed at
/// sign-up, but nobody could ever find out what theirs was to share it.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  ReferralSummary? _summary;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await ReferralsRepository.instance.me();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.inviteCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = _summary;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(l10n.inviteLoadError,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),

                  // The code itself, big enough to read aloud over a phone call.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.inviteYourCode,
                          style: TextStyle(
                            color: cs.onPrimary.withValues(alpha: 0.8),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          s?.code ?? '—',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (s?.code != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _copy(s!.code!),
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            label: Text(l10n.inviteCopy),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            // Copies the whole invite sentence rather than
                            // opening a share sheet: no share plugin ships in
                            // this app, and a half-working button is worse than
                            // an honest one.
                            onPressed: () =>
                                _copy(l10n.inviteShareText(s!.code!)),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(l10n.inviteShare),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  Text(
                    l10n.inviteExplainer,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
                  ),

                  if (s?.hasReferrer == true) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(l10n.inviteReferredBy,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _stat(context, l10n.inviteInvited, s?.total ?? 0,
                          cs.onSurface),
                      _stat(context, l10n.inviteQualified, s?.qualified ?? 0,
                          AppColors.success),
                      _stat(context, l10n.inviteRewarded, s?.rewarded ?? 0,
                          cs.primary),
                    ],
                  ),

                  if ((s?.total ?? 0) == 0) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Text(l10n.inviteNoneYet,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              // Three counts sitting side by side; tabular figures stop them
              // jittering as the numbers change.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

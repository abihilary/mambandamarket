import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../api/remote_config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/safe_bottom.dart';
import '../theme/breakpoints.dart';
import '../api/share_links.dart';
import '../web/web_share.dart';

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

  /// The share sheet with the invite and where to get the app. Falls back to
  /// the clipboard where there is no sheet (a desktop browser).
  Future<void> _share(String sentence) async {
    final l10n = context.l10n;
    final text = '$sentence\n${ShareLinks.siteBase}/download';
    if (kIsWeb) {
      // Straight from the tap, before any await: see webShare.
      final outcome =
          await webShare(title: 'Mambanda Market', text: text);
      if (outcome != WebShareOutcome.unsupported) return;
    } else {
      try {
        final result = await SharePlus.instance
            .share(ShareParams(text: text, subject: 'Mambanda Market'));
        if (result.status != ShareResultStatus.unavailable) return;
      } catch (_) {
        // No sheet on this device: copy instead, below.
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shareLinkCopied)));
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
      body: ContentFrame(
        maxWidth: Breakpoints.form,
        child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  safeBottom(context, 16),
                ),
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
                            // The share sheet — WhatsApp, SMS — with the
                            // invite sentence and the download link. It used
                            // to copy the sentence and say "Code copied",
                            // which read as a Share button that did nothing.
                            onPressed: () =>
                                _share(l10n.inviteShareText(s!.code!)),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(l10n.inviteShare),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  // What it pays, in so many words — only once the amount is
                  // set in the panel, so the screen never promises nothing.
                  if (RemoteConfig.instance.referralRewardCents > 0) ...[
                    Text(
                      l10n.inviteEarn(
                        formatPrice(RemoteConfig.instance.referralRewardCents),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/wallet'),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                    ),
                    label: Text(l10n.walletOpen),
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

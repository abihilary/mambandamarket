import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/remote_config.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../Components/safe_bottom.dart';
import '../theme/breakpoints.dart';
import '../api/share_links.dart';
import '../Components/web_share_flow.dart';

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

  Future<void> _showEditCodeDialog(String? currentCode) async {
    final controller = TextEditingController(text: currentCode ?? '');
    final l10n = context.l10n;
    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customize Referral Code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'New Referral Code',
            hintText: '3-20 alphanumeric chars',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.avatarCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.length < 3 || code.length > 20 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code must be 3-20 alphanumeric characters (a-z, 0-9).')),
                );
                return;
              }
              try {
                await ReferralsRepository.instance.updateCode(code);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } on ApiException catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: Theme.of(dialogContext).colorScheme.error),
                );
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Failed to update code.'), backgroundColor: Theme.of(dialogContext).colorScheme.error),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (success == true) {
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code updated successfully!')),
      );
    }
  }

  /// The share sheet with the invite and where to get the app. Falls back to
  /// the clipboard where there is no sheet (a desktop browser).
  Future<void> _share(String sentence) async {
    final l10n = context.l10n;
    // The link carries the code: opening it fills the code in at sign-up,
    // and the page behind it offers the download.
    final text = sentence;
    if (kIsWeb) {
      return shareOnWeb(context,
          title: 'Mambanda Market', text: text, copyText: text);
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
      appBar: AppBar(
        title: Text(l10n.inviteTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Customize Code',
            onPressed: () => _showEditCodeDialog(s?.code),
          ),
        ],
      ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.inviteYourCode,
                              style: TextStyle(
                                color: cs.onPrimary.withValues(alpha: 0.8),
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showEditCodeDialog(s?.code),
                              child: Icon(Icons.edit, size: 14, color: cs.onPrimary.withValues(alpha: 0.9)),
                            ),
                          ],
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
                            onPressed: () => _share(l10n.inviteShareText(
                                s!.code!, ShareLinks.invite(s.code!).toString())),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(l10n.inviteShare),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
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
                  // The rest of the programme, as the panel set it.
                  for (final m in RemoteConfig.instance.referralMilestones)
                    _rule(context, Icons.emoji_events_outlined,
                        l10n.inviteMilestone(formatPrice(m.bonusCents), m.count)),
                  if (RemoteConfig.instance.referralSubscriptionPercent > 0)
                    _rule(
                      context,
                      Icons.workspace_premium_outlined,
                      RemoteConfig.instance.referralSubscriptionMonths > 0
                          ? l10n.inviteCommissionMonths(
                              _percent(RemoteConfig.instance.referralSubscriptionPercent),
                              RemoteConfig.instance.referralSubscriptionMonths)
                          : l10n.inviteCommission(
                              _percent(RemoteConfig.instance.referralSubscriptionPercent)),
                    ),
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
                      _stat(context, l10n.inviteRewarded, s?.rewarded ?? 0,
                          AppColors.success),
                      _statText(context, l10n.inviteEarnedTotal,
                          formatPrice(s?.earnedCents ?? 0), cs.primary),
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

                  if (s?.items.isNotEmpty == true) ...[
                    const SizedBox(height: 28),
                    Text(
                      l10n.inviteHistory,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...s!.items.map((item) {
                      final paid = item.earnedCents > 0;
                      final date = DateTime.tryParse(item.createdAt)?.toLocal();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            paid ? Icons.card_giftcard : Icons.person_add_alt_1_outlined,
                            color: paid ? AppColors.success : cs.onSurfaceVariant,
                          ),
                          title: Text(item.name ?? l10n.inviteSomeone),
                          subtitle: Text(l10n.inviteJoinedOn(date == null
                              ? item.createdAt.split('T').first
                              : MaterialLocalizations.of(context).formatMediumDate(date))),
                          trailing: Text(
                            paid ? '+${formatPrice(item.earnedCents)}' : l10n.inviteUnpaid,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: paid ? AppColors.success : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  if ((s?.total ?? 0) == 0 && s?.items.isEmpty == true) ...[
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

  /// One line of the programme's rules, under the headline reward.
  Widget _rule(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
          ),
        ],
      ),
    );
  }

  /// 10 → "10", 7.5 → "7.5".
  static String _percent(num p) =>
      p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  Widget _statText(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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

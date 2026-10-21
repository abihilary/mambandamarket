import 'package:flutter/material.dart';

import '../Components/safe_bottom.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/user_wallet.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// What inviting friends has earned, and taking it out.
///
/// The balance is the sum of the ledger on the server, never a number kept
/// here. A withdrawal is a request: Mambanda sends the money to MTN MoMo or
/// Orange Money by hand and the app hears back by push either way.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  PersonalWalletSummary? _summary;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await UserWalletRepository.instance.summary();
      if (!mounted) return;
      setState(() {
        _summary = s;
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

  String _entryLabel(String kind) {
    final l10n = context.l10n;
    return switch (kind) {
      'referral_reward' => l10n.walletEntryReward,
      'withdrawal' => l10n.walletEntryWithdrawal,
      'withdrawal_reversal' => l10n.walletEntryReversal,
      _ => l10n.walletEntryAdjustment,
    };
  }

  String _method(String m) => m == 'orange_money' ? 'Orange Money' : 'MTN MoMo';

  Future<void> _openWithdraw(PersonalWalletSummary s) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WithdrawSheet(summary: s),
    );
    if (sent == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.walletWithdrawDone),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _loading = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final s = _summary;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: RefreshIndicator(
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
                  if (_failed || s == null) ...[
                    const SizedBox(height: 48),
                    Center(
                      child: Text(
                        l10n.walletLoadError,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton(
                        onPressed: _load,
                        child: Text(l10n.retry),
                      ),
                    ),
                  ] else ...[
                    // Balance.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tokens.accentFill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.walletBalance,
                            style: TextStyle(
                              color: tokens.onAccentFill.withValues(
                                alpha: 0.75,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatPrice(s.balanceCents),
                            style: TextStyle(
                              color: tokens.onAccentFill,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.onAccentFill,
                                foregroundColor: tokens.accentFill,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: s.canWithdraw
                                  ? () => _openWithdraw(s)
                                  : null,
                              child: Text(l10n.walletWithdraw),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.walletMinimum(
                              formatPrice(s.minWithdrawalCents),
                            ),
                            style: TextStyle(
                              color: tokens.onAccentFill.withValues(
                                alpha: 0.75,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.rewardCents > 0
                          ? l10n.walletRewardExplainer(
                              formatPrice(s.rewardCents),
                            )
                          : l10n.walletRewardOff,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    if (s.withdrawals.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.walletWithdrawals,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final w in s.withdrawals)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            w.status == 'paid'
                                ? Icons.check_circle_outline
                                : w.status == 'rejected'
                                ? Icons.undo
                                : Icons.schedule,
                            color: w.status == 'paid'
                                ? AppColors.success
                                : w.status == 'rejected'
                                ? cs.error
                                : cs.onSurfaceVariant,
                          ),
                          title: Text(
                            '${formatPrice(w.amountCents)} · ${_method(w.method)} ${w.msisdn}',
                          ),
                          subtitle: Text(switch (w.status) {
                            'paid' =>
                              w.providerRef == null
                                  ? l10n.walletStatusPaid
                                  : '${l10n.walletStatusPaid} · ${w.providerRef}',
                            'rejected' =>
                              w.note == null
                                  ? l10n.walletStatusRejected
                                  : '${l10n.walletStatusRejected} · ${w.note}',
                            _ => l10n.walletStatusRequested,
                          }),
                        ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      l10n.walletHistory,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (s.entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l10n.walletEmpty,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    else
                      for (final e in s.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_entryLabel(e.kind)),
                          subtitle: e.createdAt == null
                              ? null
                              : Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatMediumDate(e.createdAt!.toLocal()),
                                ),
                          trailing: Text(
                            '${e.amountCents >= 0 ? '+' : '−'}${formatPrice(e.amountCents.abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: e.amountCents >= 0
                                  ? AppColors.success
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final PersonalWalletSummary summary;
  const _WithdrawSheet({required this.summary});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.summary.balanceCents.toString(),
  );
  late final TextEditingController _number = TextEditingController(
    text: AuthService.instance.me.value?.profile?.phone ?? '',
  );
  String _method = 'mtn_momo';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    final l10n = context.l10n;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await UserWalletRepository.instance.withdraw(
        amountCents: int.parse(_amount.text.trim()),
        method: _method,
        msisdn: _number.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _sending = false;
        _error = switch (e.code) {
          'below_minimum' => l10n.walletErrorMinimum(
            formatPrice(widget.summary.minWithdrawalCents),
          ),
          'insufficient_balance' => l10n.walletErrorBalance,
          'invalid_msisdn' => l10n.walletErrorNumber,
          _ => e.message,
        };
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = l10n.walletErrorGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.summary;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom(context)),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.walletWithdraw,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.walletWithdrawHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mtn_momo', label: Text('MTN MoMo')),
                ButtonSegment(
                  value: 'orange_money',
                  label: Text('Orange Money'),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (v) => setState(() => _method = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.walletNumber,
                hintText: '677 12 34 56',
                border: border,
              ),
              validator: (v) {
                final d = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                return d.length < 9 ? l10n.walletErrorNumber : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.walletAmount,
                suffixText: 'FCFA',
                border: border,
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < s.minWithdrawalCents) {
                  return l10n.walletErrorMinimum(
                    formatPrice(s.minWithdrawalCents),
                  );
                }
                if (n > s.balanceCents) return l10n.walletErrorBalance;
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.walletWithdrawSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

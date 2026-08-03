import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Status pills shared by the buyer's order list/detail and the company
/// dashboard, so one status never gets two different colours or wordings
/// depending on which side of the sale you're looking from.

/// Display label for an order status (`pending_payment`, `paid`, …). Unknown
/// values fall through to the raw code rather than rendering blank.
String orderStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'pending_payment' => l10n.orderStatusPendingPayment,
      'paid' => l10n.orderStatusPaid,
      'fulfilled' => l10n.orderStatusFulfilled,
      'completed' => l10n.orderStatusCompleted,
      'cancelled' => l10n.orderStatusCancelled,
      'refunded' => l10n.orderStatusRefunded,
      _ => status,
    };

/// Resolved against the active theme so a pill stays legible on either ground:
/// the money states go through the semantic tokens, the brand state through the
/// scheme, and the in-transit blue flips tone with the brightness.
Color orderStatusColor(BuildContext context, String status) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return switch (status) {
    'pending_payment' => AppColors.warning,
    'paid' => theme.colorScheme.primary,
    'fulfilled' => isDark ? Colors.blue.shade300 : Colors.blue.shade700,
    'completed' => AppColors.success,
    'cancelled' => theme.colorScheme.onSurfaceVariant,
    'refunded' => AppColors.danger,
    _ => theme.colorScheme.onSurfaceVariant,
  };
}

String payoutStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'pending' => l10n.payoutStatusPending,
      'processing' => l10n.payoutStatusProcessing,
      'paid' => l10n.payoutStatusPaid,
      'failed' => l10n.payoutStatusFailed,
      'cancelled' => l10n.payoutStatusCancelled,
      _ => status,
    };

Color payoutStatusColor(BuildContext context, String status) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return switch (status) {
    'pending' => AppColors.warning,
    'processing' => isDark ? Colors.blue.shade300 : Colors.blue.shade700,
    'paid' => AppColors.success,
    'failed' => AppColors.danger,
    'cancelled' => theme.colorScheme.onSurfaceVariant,
    _ => theme.colorScheme.onSurfaceVariant,
  };
}

/// Small tinted pill. [isPayout] switches the label/colour table without
/// callers having to pass both.
class StatusChip extends StatelessWidget {
  final String status;
  final bool isPayout;

  const StatusChip({super.key, required this.status, this.isPayout = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = isPayout
        ? payoutStatusColor(context, status)
        : orderStatusColor(context, status);
    final label =
        isPayout ? payoutStatusLabel(l10n, status) : orderStatusLabel(l10n, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

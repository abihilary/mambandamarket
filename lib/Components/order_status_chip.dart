import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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

Color orderStatusColor(String status) => switch (status) {
      'pending_payment' => Colors.orange.shade800,
      'paid' => Colors.indigo,
      'fulfilled' => Colors.blue.shade700,
      'completed' => Colors.green.shade700,
      'cancelled' => Colors.grey.shade600,
      'refunded' => Colors.red.shade700,
      _ => Colors.grey.shade600,
    };

String payoutStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'pending' => l10n.payoutStatusPending,
      'processing' => l10n.payoutStatusProcessing,
      'paid' => l10n.payoutStatusPaid,
      'failed' => l10n.payoutStatusFailed,
      'cancelled' => l10n.payoutStatusCancelled,
      _ => status,
    };

Color payoutStatusColor(String status) => switch (status) {
      'pending' => Colors.orange.shade800,
      'processing' => Colors.blue.shade700,
      'paid' => Colors.green.shade700,
      'failed' => Colors.red.shade700,
      'cancelled' => Colors.grey.shade600,
      _ => Colors.grey.shade600,
    };

/// Small tinted pill. [isPayout] switches the label/colour table without
/// callers having to pass both.
class StatusChip extends StatelessWidget {
  final String status;
  final bool isPayout;

  const StatusChip({super.key, required this.status, this.isPayout = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color =
        isPayout ? payoutStatusColor(status) : orderStatusColor(status);
    final label =
        isPayout ? payoutStatusLabel(l10n, status) : orderStatusLabel(l10n, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

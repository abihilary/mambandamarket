import 'package:flutter/material.dart';

import '../api/read_result.dart';
import '../l10n/l10n.dart';

/// One quiet row above content shown from the device.
///
/// [reason] says why the saved copy is standing in: "you're offline" is only
/// said when it is true; a server that could not answer gets its own wording.
/// Null renders nothing, so callers can pass a notifier's value straight in.
class SavedNote extends StatelessWidget {
  const SavedNote({super.key, required this.reason, this.actionsOff = false});

  /// Null renders nothing.
  final SavedReason? reason;

  /// Adds `savedCopyActionsOff` below: the screen's actions are switched off
  /// until fresh data arrives.
  final bool actionsOff;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    if (reason == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final text = switch (reason) {
      SavedReason.offline => l10n.savedCopyNote,
      SavedReason.serverUnavailable => l10n.savedCopyServerNote,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 32),
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.cloud_off_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: style),
                  if (actionsOff) ...[
                    const SizedBox(height: 2),
                    Text(l10n.savedCopyActionsOff, style: style),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

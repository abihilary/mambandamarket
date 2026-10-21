import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../web/web_share.dart';

/// Sharing on the web build, start to finish.
///
/// The browser's share sheet where it has one (phones, Safari, Edge). Where it
/// has none — most desktop browsers — [copyText] goes on the clipboard and a
/// message says so. Where the browser refuses the clipboard as well, the text
/// is shown in a dialog to select and copy by hand. Every path ends in
/// something visible; a Share button that does nothing reads as broken.
///
/// Call it straight from the tap: browsers only open a share sheet, or allow a
/// copy, inside the user's gesture.
Future<void> shareOnWeb(
  BuildContext context, {
  required String title,
  required String text,
  required String copyText,
}) async {
  final outcome = await webShare(title: title, text: text);
  if (outcome != WebShareOutcome.unsupported) return;
  final copied = await webCopy(copyText);
  if (!context.mounted) return;
  final l10n = context.l10n;
  if (copied) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shareLinkCopied)));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.shareCopyManualTitle),
      content: SelectableText(copyText),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
}

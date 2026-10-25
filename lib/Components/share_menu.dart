import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../web/web_share.dart';
import 'web_share_flow.dart';

/// Sharing from a desktop browser: our own small menu under the share button,
/// "Copy link" first.
///
/// A desktop has no share sheet worth the name. Where the browser lacks one
/// the old flow copied silently, and the OS sheets on Windows and macOS are
/// unfamiliar enough that people paste whatever ends up on the clipboard into
/// the address bar. So the one thing this copies is the bare link — the page
/// behind it builds WhatsApp's and Facebook's previews by itself. The only row
/// that sends words with the link is WhatsApp, because there the person chose
/// to send a message.
///
/// [canShare] is whether the browser has `navigator.share`, for the "More
/// options…" row; by default the browser is asked. Without it (Firefox
/// desktop, Chrome on Linux) the row would only copy the link again.
Future<void> showShareMenu(
  BuildContext context, {
  required BuildContext anchor,
  required String title,
  required String priceText,
  required String link,
  bool? canShare,
  @visibleForTesting Future<bool> Function(String text)? copy,
}) async {
  final button = anchor.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (button == null || overlay == null) return;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  await showMenu<void>(
    context: context,
    position: position,
    constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
    items: [
      _ShareMenuBody(
        outer: context,
        title: title,
        priceText: priceText,
        link: link,
        canShare: canShare ?? webCanShare(),
        copy: copy ?? webCopy,
      ),
    ],
  );
}

/// The whole menu as one entry, so the copy row can confirm in place while the
/// menu stays open — a PopupMenuItem closes on every tap.
class _ShareMenuBody extends PopupMenuEntry<void> {
  final BuildContext outer;
  final String title;
  final String priceText;
  final String link;
  final bool canShare;
  final Future<bool> Function(String text) copy;

  const _ShareMenuBody({
    required this.outer,
    required this.title,
    required this.priceText,
    required this.link,
    required this.canShare,
    required this.copy,
  });

  @override
  double get height => 260;

  @override
  bool represents(void value) => false;

  @override
  State<_ShareMenuBody> createState() => _ShareMenuBodyState();
}

class _ShareMenuBodyState extends State<_ShareMenuBody> {
  /// null until a copy is tried; then whether the clipboard took it.
  bool? _copied;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  /// Straight from the tap: browsers only allow a copy inside the gesture.
  Future<void> _copy() async {
    final ok = await widget.copy(widget.link);
    if (!mounted) return;
    setState(() => _copied = ok);
    _reset?.cancel();
    if (ok) {
      _reset = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = null);
      });
    }
  }

  void _open(String url) {
    Navigator.of(context).pop();
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _whatsApp() => _open('https://wa.me/?text='
      '${Uri.encodeComponent('${widget.title} — ${widget.priceText}\n${widget.link}')}');

  void _facebook() => _open('https://www.facebook.com/sharer/sharer.php?u='
      '${Uri.encodeComponent(widget.link)}');

  void _more() {
    Navigator.of(context).pop();
    // The browser's own sheet, link in its link field. Where it turns out not
    // to have one, shareOnWeb copies the link and says so.
    shareOnWeb(widget.outer,
        title: widget.title, url: widget.link, copyText: widget.link);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ink = context.tokens.accentInk;
    final shown = widget.link.replaceFirst(RegExp(r'^https?://'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(l10n.shareMenuTitle,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            // Selectable, for the person who would rather copy it by hand —
            // and the fallback when the browser refuses the clipboard.
            child: SelectableText(
              shown,
              maxLines: 1,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 6),
          _MenuRow(
            icon: Icons.link,
            label: l10n.shareCopyLink,
            primary: true,
            onTap: _copy,
            trailing: switch (_copied) {
              true => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 16, color: ink),
                    const SizedBox(width: 4),
                    Text(l10n.shareCopied,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ink)),
                  ],
                ),
              false => Flexible(
                  child: Text(
                    l10n.shareCopyManualTitle,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              null => null,
            },
          ),
          _MenuRow(
            icon: Icons.chat_outlined,
            label: l10n.shareWhatsApp,
            onTap: _whatsApp,
          ),
          _MenuRow(
            icon: Icons.facebook,
            label: l10n.shareFacebook,
            onTap: _facebook,
          ),
          if (widget.canShare)
            _MenuRow(
              icon: Icons.more_horiz,
              label: l10n.shareMoreOptions,
              onTap: _more,
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final Widget? trailing;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? context.tokens.accentInk : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

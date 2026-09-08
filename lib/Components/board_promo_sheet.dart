import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/board_model.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'home_board.dart';

/// A promotion, explained without leaving the feed.
///
/// A sheet rather than a dialog: this is content — a picture, a paragraph, and
/// somewhere to go — and drag-to-dismiss is the right way out of an
/// advertisement. A dialog with a barrier says "answer me"; this only says
/// "here is what the offer is".
///
/// No sign-in guard, unlike the report and support sheets. A promotion is
/// public, and asking somebody to sign in to read one would be a strange way to
/// begin.
Future<void> showBoardPromoSheet(
  BuildContext context, {
  required BoardPromo promo,
  void Function(String slug)? onCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The shell's bottom bar would otherwise sit on top of it.
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BoardPromoSheet(promo: promo, onCategory: onCategory),
  );
}

class _BoardPromoSheet extends StatelessWidget {
  const _BoardPromoSheet({required this.promo, this.onCategory});

  final BoardPromo promo;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final title = pickLocalised(promo.title, locale);
    final body = pickLocalised(promo.body, locale);
    final imageUrl = promo.imageUrl;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    // No spinner, for the same reason the board has none: it
                    // either appears or it does not, and a promotion is not
                    // worth a loading state.
                    placeholder: (_, __) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (title != null)
              Text(
                title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            for (final action in promo.actions) ...[
              _SheetButton(
                label: pickLocalised(action.label, locale) ?? '',
                primary: action.style == BoardActionStyle.primary,
                onTap: () {
                  // Close first, then go. Pushing a screen or opening a browser
                  // with the sheet still up leaves it sitting there when they
                  // come back — and this context is dead once it pops, so the
                  // link is dispatched with the one underneath.
                  final navigatorContext = Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);
                  openBoardLink(navigatorContext, action.link, onCategory: onCategory);
                },
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.promoClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    if (!primary) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          // accentFill is a background; onAccentFill is what goes on top of it.
          backgroundColor: tokens.accentFill,
          foregroundColor: tokens.onAccentFill,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

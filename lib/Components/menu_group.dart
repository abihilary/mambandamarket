import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A cluster of related rows on one card, as the deck groups them.
///
/// Replaces bare ListTiles sitting at the top level of a ListView, where
/// nothing said which rows belonged together and a destructive action looked
/// exactly like a navigation one.
class MenuGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const MenuGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        // Inset to line up with the titles, not the icon tiles — a full-bleed
        // rule cuts the card in half instead of separating two rows.
        rows.add(Divider(height: 1, indent: 68, color: theme.dividerColor));
      }
      rows.add(children[i]);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: tokens.groupSurface,
        borderRadius: BorderRadius.circular(20),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.dividerColor)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// One row inside a [MenuGroup].
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Destructive rows carry the danger colour on the icon, the label and the
  /// chevron, so "Log out" cannot be mistaken for one more place to navigate.
  final bool danger;

  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final ink = danger ? AppColors.danger : tokens.accentInk;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: danger
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : tokens.iconTile,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 21, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: danger ? AppColors.danger : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, size: 22, color: ink),
          ],
        ),
      ),
    );
  }
}

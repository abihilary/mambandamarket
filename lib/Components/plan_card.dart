import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// The plan card, as a pane of glass.
///
/// Blur needs something behind it or it costs a frame to render nothing, and
/// the account list has nothing behind it — a flat scaffold blurs to the same
/// flat scaffold. So the card brings its own: two lime blobs painted underneath
/// and then smeared by the filter, which is how a frosted panel gets its colour
/// in every design that does this well. The blobs are inside the card's own
/// clip, so nothing of them shows unblurred.
///
/// Cheap on purpose: two gradients and one small static pane. Nothing here
/// redraws while the list scrolls.
class PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const PlanCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final dark = theme.brightness == Brightness.dark;

    // Light needs a base with some body to it before the blur: white at a
    // hair over half, so the lime reads through as a wash rather than a stain,
    // and the text sits on something. Dark can be sheerer — the blobs are
    // already dim against it.
    final tint = dark
        ? const Color(0xC2131610)
        : Colors.white.withValues(alpha: 0.62);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -40,
            child: _Blob(
                color: tokens.accentFill.withValues(alpha: dark ? 0.26 : 0.55),
                size: 170),
          ),
          Positioned(
            right: -40,
            bottom: -50,
            child: _Blob(
                color: tokens.accentFill.withValues(alpha: dark ? 0.15 : 0.34),
                size: 190),
          ),
          GlassSurface(
            sigma: 26,
            tint: tint,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      color: tokens.accentInk,
                      shadows: [Shadow(color: tokens.iconGlow, blurRadius: 10)]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft disc of colour. Only ever seen through a blur.
class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      );
}

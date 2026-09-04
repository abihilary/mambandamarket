import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A bar you can see through.
///
/// Blurs whatever is behind it and paints [AppTokens.glassTint] over the
/// result. Both halves matter: blur alone leaves a smeared photograph, which
/// nothing can be read on top of, and the tint alone is just an opaque bar.
///
/// **The clip is not optional.** `BackdropFilter` filters everything painted
/// behind it inside the current clip, so without a `ClipRect` it samples — and
/// repaints — the entire screen behind the widget rather than the strip it
/// occupies.
///
/// Content has to be allowed to pass underneath for any of this to be visible:
/// a `Scaffold` needs `extendBody: true`, or the only thing behind the bar is
/// the scaffold's own background and the blur costs a frame to render nothing.
///
/// Cost: this is the most expensive thing the app draws. Impeller's blur is far
/// cheaper than Skia's was, and the surface is a 68px strip rather than a full
/// screen, but on a low-end phone it is still real. [sigma] is the dial — the
/// cost of a Gaussian blur scales with it — and it is deliberately modest.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double sigma;

  /// A hairline along the top edge. Without it the bar has no boundary at all
  /// where a pale photo scrolls under a pale tint, and the labels look like
  /// they are floating on the content.
  final bool topBorder;

  const GlassSurface({
    super.key,
    required this.child,
    this.sigma = 18,
    this.topBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glassTint,
            border: topBorder
                ? Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                    ),
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

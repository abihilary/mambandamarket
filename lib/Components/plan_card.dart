import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// The seller-progress card, as a pane of glass.
///
/// Blur needs something behind it or it costs a frame to render nothing, and
/// the account list has nothing behind it — a flat scaffold blurs to the same
/// flat scaffold. So the card brings its own: two lime blobs painted underneath
/// and then smeared by the filter, which is how a frosted panel gets its colour
/// in every design that does this well. The blobs are inside the card's own
/// clip, so nothing of them shows unblurred.
///
/// Numbers are real. The ring and the bar both read the listing quota from
/// `/me` — published against the plan's limit — rather than an invented
/// earnings goal: the mockup used earnings as a placeholder, and a placeholder
/// is not a thing to ship.
class PlanCard extends StatelessWidget {
  /// "Seller progress".
  final String title;

  /// The plan, for the pill: "Free plan", "Plan: Pro".
  final String planLabel;

  /// "Listings published".
  final String publishedLabel;

  final int activeListings;

  /// null == unlimited: the ring fills and the bar gives way to a word.
  final int? listingLimit;

  final String actionLabel;
  final VoidCallback onAction;

  const PlanCard({
    super.key,
    required this.title,
    required this.planLabel,
    required this.publishedLabel,
    required this.activeListings,
    required this.listingLimit,
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
        : Colors.white.withValues(alpha: 0.66);

    final limit = listingLimit;
    final fraction = limit == null || limit == 0
        ? 1.0
        : (activeListings / limit).clamp(0.0, 1.0);
    final pct = (fraction * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -40,
            child: _Blob(
              color: tokens.accentFill.withValues(alpha: dark ? 0.26 : 0.55),
              size: 180,
            ),
          ),
          Positioned(
            right: -40,
            bottom: -50,
            child: _Blob(
              color: tokens.accentFill.withValues(alpha: dark ? 0.15 : 0.34),
              size: 200,
            ),
          ),
          GlassSurface(
            sigma: 26,
            tint: tint,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _PlanPill(label: planLabel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _QuotaRing(
                        fraction: fraction,
                        center: limit == null
                            ? '$activeListings'
                            : '$activeListings/$limit',
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              publishedLabel,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (limit == null)
                              Text(
                                '∞',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.accentInk,
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: fraction,
                                        minHeight: 8,
                                        backgroundColor: theme
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.12),
                                        valueColor: AlwaysStoppedAnimation(
                                          tokens.accentFill,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _ChangePlanButton(
                                label: actionLabel,
                                onTap: onAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan name, as a pill in the top-right corner.
class _PlanPill extends StatelessWidget {
  final String label;
  const _PlanPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.accentFill.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.accentFill.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tokens.accentInk,
        ),
      ),
    );
  }
}

/// The ring, with the fraction at its centre.
class _QuotaRing extends StatelessWidget {
  final double fraction;
  final String center;
  const _QuotaRing({required this.fraction, required this.center});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.12,
              ),
              valueColor: AlwaysStoppedAnimation(tokens.accentFill),
            ),
          ),
          Text(
            center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// "Change plan", filled in lime like the deck's.
class _ChangePlanButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChangePlanButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.accentFill,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.onAccentFill,
            ),
          ),
        ),
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
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

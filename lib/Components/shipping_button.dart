import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// Bottom clearance a feed showing the shipping button must reserve.
///
/// The 96 every scrollable already carries was sized for the bar and the
/// publish disc. This sits above that, so without the extra the last row of
/// the grid stays permanently half-covered.
double shippingButtonClearance(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom + 140;

/// The way in to asking us to ship something.
///
/// Three deliberate choices, all of them about not fighting what is already on
/// the screen:
///
///   * **Not lime.** `tokens.accentFill` is the publish disc's whole identity —
///     the lime circle is how you post. A second lime object sixteen pixels
///     away would make both of them mean less.
///   * **Not a lorry glyph.** `category_icons.dart` already maps one to the
///     Vehicles branch, and order fulfilment uses the same one. A parcel is
///     free of both.
///   * **Words at rest.** Nothing in this app has ever mentioned shipping, so
///     a bare icon in the corner is a thing nobody taps. It keeps its label
///     until the feed starts moving, then collapses rather than disappearing,
///     so it is still there when they stop.
class ShippingButton extends StatelessWidget {
  const ShippingButton({super.key, required this.extended, required this.onPressed});

  final bool extended;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: 3,
      color: scheme.surfaceContainerHigh,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: StadiumBorder(
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 22, color: context.tokens.accentInk),
                  if (extended) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.shipFabLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

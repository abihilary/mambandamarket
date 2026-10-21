import 'package:flutter/material.dart';

/// The little bag from inside the M, as the brand's small mark.
///
/// For the places that used to borrow `Icons.storefront` to mean "Mambanda" —
/// the sign-in screens, "From Mambanda", "Deliver my purchase" — where a
/// generic shop said nothing about whose shop it was. Places where the icon
/// means an actual shop (a business's storefront, the Seller role) keep it.
///
/// Drawn as a vector (assets/brand/bag.svg) and rendered to a 512px PNG, so it
/// stays sharp up to the 72px sign-in header at 3x. Its rim is lime and its
/// inside near-black, so it reads on light and dark grounds alike — but not on
/// a lime fill, where the rim disappears.
class BrandBag extends StatelessWidget {
  const BrandBag({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/bag.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
}

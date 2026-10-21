import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Bottom padding for a sheet or the end of a scroll: clear of the keyboard
/// when it is up, clear of the system navigation bar when it is not.
///
/// The app draws edge-to-edge (targetSdk 35+ forces it), so the gesture bar or
/// the three-button bar sits *over* the bottom of every screen. `viewInsets`
/// is the keyboard only — a sheet padded with it alone puts its button under
/// the bar on phones like the Galaxy Ultra. The keyboard's inset is measured
/// from the screen's bottom edge and already covers the bar, so the two are
/// not added: whichever is taller wins.
double safeBottom(BuildContext context, [double extra = 20]) {
  final insets = MediaQuery.viewInsetsOf(context).bottom;
  final bar = MediaQuery.viewPaddingOf(context).bottom;
  return math.max(insets, bar) + extra;
}

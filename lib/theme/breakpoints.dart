import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Width breakpoints. Below [medium] the app is the phone layout exactly as it
/// ships on Android; the web build is the only place the wider ones are seen
/// in practice, though a tablet or a foldable gets them too.
///
/// | width      | layout                                   | navigation          |
/// |------------|------------------------------------------|---------------------|
/// | < 600      | phone                                    | bottom bar          |
/// | 600 – 839  | phone, wider grids, content capped       | bottom bar          |
/// | 840 +      | desktop                                  | sidebar             |
/// | 1200 +     | desktop                                  | sidebar with labels |
abstract final class Breakpoints {
  static const double medium = 600;
  static const double wide = 840;
  static const double large = 1200;

  /// Content caps, so a 1920px window shows a page rather than a stretched phone.
  static const double feed = 1280;
  static const double dashboard = 1100;
  static const double form = 720;
  static const double auth = 440;
  static const double sheet = 560;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// 600 and up: wider grids and capped content, still the bottom bar.
  bool get isMediumUp => screenWidth >= Breakpoints.medium;

  /// 840 and up: the desktop layout with the sidebar.
  bool get isWideLayout => screenWidth >= Breakpoints.wide;

  /// 1200 and up: the sidebar shows its labels.
  bool get isLargeLayout => screenWidth >= Breakpoints.large;
}

/// Centres [child] and caps its width, leaving whatever is behind it (a
/// background, an app bar) edge to edge. Used per screen rather than once
/// around the app, so `MediaQuery` keeps telling the truth about the window.
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.feed,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    // Narrower than the cap — every phone — it is not there at all, so the
    // phone layout is exactly what it was before this existed.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Horizontal padding that centres a [maxWidth] column inside a sliver list or
/// a scroll view, for screens that cannot wrap their scrollable in a
/// [ContentFrame] without losing an edge-to-edge app bar.
EdgeInsets frameInsets(
  BuildContext context, {
  double maxWidth = Breakpoints.feed,
  double min = 0,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
  final h = side < min ? min : side;
  return EdgeInsets.symmetric(horizontal: h);
}

/// Lets a mouse or trackpad drag every rail, carousel and page view, not only
/// a finger. Flutter's default leaves mouse out, which on desktop made every
/// horizontal list look frozen.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

/// A [GestureDetector] that also shows the hand cursor, for the custom
/// tappables (cards, chips, tiles) that are not Material buttons and so never
/// told a mouse they could be clicked.
class Tappable extends StatelessWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onLongPress != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: behavior,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: child,
      ),
    );
  }
}

/// Bottom padding the end of a tab's scrollable needs to clear the shell's
/// chrome: the bottom bar and the publish disc on a phone, nothing but a margin
/// beside the sidebar.
double shellBottomClearance(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.wide
        ? 24
        : MediaQuery.viewPaddingOf(context).bottom + 96;

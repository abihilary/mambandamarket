import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Brand tokens that `ColorScheme` has no honest slot for.
///
/// The presentation deck is drawn entirely on black, where lime carries
/// everything: fills, labels, icons, chevrons. That does not survive a move to
/// a light ground. Measured against white, `lime` scores **1.43:1** and even
/// `limeDeep` only **2.34:1** — both far under the 4.5:1 needed for text, so a
/// literal port of the deck would leave half the light theme unreadable.
///
/// The fix is to stop treating "the accent" as one colour. Lime as a *fill* is
/// fine anywhere, because what sits on it is near-black ([onAccentFill], 13.8:1
/// against lime). Lime as *ink* is the part that has to change with the ground.
///
/// This lives in a ThemeExtension rather than in `ColorScheme.primary` on
/// purpose: light-mode `primary` is `ink`, and dozens of widgets already read
/// `colorScheme.primary` for text. Recolouring it to lime would make every one
/// of those illegible in a single edit.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Lime, in both themes. Only ever a background — never text.
  final Color accentFill;

  /// What sits on [accentFill]. Near-black in both themes.
  final Color onAccentFill;

  /// The accent as text, icons and chevrons. Lime in the dark; a deepened lime
  /// in the light, where the bright one cannot be read.
  final Color accentInk;

  /// Centre of the small rounded icon tiles beside a settings row.
  ///
  /// The tile is a radial gradient from this to [iconTileEdge], not a flat
  /// fill: the deck's tiles are lit from the middle, which is what gives them
  /// the slight dimensionality a flat swatch cannot.
  final Color iconTile;

  /// Outer stop of that gradient — near the card it sits on.
  final Color iconTileEdge;

  /// Bloom around the glyph itself.
  ///
  /// On the icon rather than the tile: a shadow on the box haloes a rounded
  /// square, and what the deck glows is the mark inside it.
  final Color iconGlow;

  /// Ground for a grouped card — the deck's clusters of related rows.
  final Color groupSurface;

  /// Tint painted over a blurred backdrop.
  ///
  /// Translucent on purpose: the blur alone leaves a smeared photo, which is
  /// unreadable behind labels. The tint is what turns it into a surface. Its
  /// alpha is the whole trick — too opaque and it is just a bar, too sheer and
  /// the text sits on whatever colour happens to scroll underneath it.
  final Color glassTint;

  const AppTokens({
    required this.accentFill,
    required this.onAccentFill,
    required this.accentInk,
    required this.iconTile,
    required this.iconTileEdge,
    required this.iconGlow,
    required this.groupSurface,
    required this.glassTint,
  });

  static const dark = AppTokens(
    accentFill: AppColors.lime,
    onAccentFill: AppColors.onLime,
    accentInk: AppColors.lime,
    // A lime wash, not darkElevated: that is the same colour as groupSurface,
    // so the tile disappeared into the card it sits on and only the glyph
    // showed. The deck's tiles are visible objects.
    iconTile: Color(0x2EC9E505),
    iconTileEdge: Color(0x0AC9E505),
    iconGlow: Color(0x73C9E505),
    groupSurface: AppColors.darkElevated,
    // Darker and more opaque than the light equivalent: a bright photo behind
    // a sheer dark bar washes it out, and white labels then sit on grey.
    glassTint: Color(0xCC1A1C18),
  );

  static final light = AppTokens(
    accentFill: AppColors.lime,
    onAccentFill: AppColors.onLime,
    accentInk: AppColors.limeInk,
    // A lime wash rather than a grey one, so the tiles still read as branded
    // without putting bright lime next to body text.
    iconTile: AppColors.lime.withValues(alpha: 0.30),
    iconTileEdge: AppColors.lime.withValues(alpha: 0.08),
    // Softer than the dark theme's. A bright halo on a pale ground stops
    // reading as light and starts reading as a printing mistake.
    iconGlow: AppColors.lime.withValues(alpha: 0.32),
    groupSurface: AppColors.lightSurface,
    glassTint: AppColors.lightSurface.withValues(alpha: 0.72),
  );

  /// Shorthand: `context.tokens.accentInk`.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? dark;

  @override
  AppTokens copyWith({
    Color? accentFill,
    Color? onAccentFill,
    Color? accentInk,
    Color? iconTile,
    Color? iconTileEdge,
    Color? iconGlow,
    Color? groupSurface,
    Color? glassTint,
  }) =>
      AppTokens(
        accentFill: accentFill ?? this.accentFill,
        onAccentFill: onAccentFill ?? this.onAccentFill,
        accentInk: accentInk ?? this.accentInk,
        iconTile: iconTile ?? this.iconTile,
        iconTileEdge: iconTileEdge ?? this.iconTileEdge,
        iconGlow: iconGlow ?? this.iconGlow,
        groupSurface: groupSurface ?? this.groupSurface,
        glassTint: glassTint ?? this.glassTint,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
      onAccentFill: Color.lerp(onAccentFill, other.onAccentFill, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      iconTile: Color.lerp(iconTile, other.iconTile, t)!,
      iconTileEdge: Color.lerp(iconTileEdge, other.iconTileEdge, t)!,
      iconGlow: Color.lerp(iconGlow, other.iconGlow, t)!,
      groupSurface: Color.lerp(groupSurface, other.groupSurface, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
}

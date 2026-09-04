import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// The Mambanda Market palette.
///
/// Sampled from the brand logo rather than guessed: the monogram's lime runs
/// #B4D804 → #DDF106, averaging [lime]. The plate behind it is pure black, and
/// the promo material keeps a violet glow purely as ambient decoration — never
/// as an action colour, so it lives here as [glow] and nothing else.
abstract final class AppColors {
  static const lime = Color(0xFFC9E505);
  static const limeBright = Color(0xFFDDF106);
  static const limeDeep = Color(0xFF9DB404);

  /// The accent, deepened until it can be read on a light ground.
  ///
  /// Measured: [lime] scores 1.43:1 against white and [limeDeep] 2.34:1, both
  /// well under the 4.5:1 a label needs. This one is 5.97:1 on white and
  /// 5.62:1 on [lightGround], and still reads as the brand rather than as an
  /// unrelated olive. Light theme only — in the dark, plain [lime] is 12.9:1
  /// on [darkSurface] and needs no help.
  static const limeInk = Color(0xFF5C6A02);

  /// Lime is far too bright to carry white text — anything sitting on it uses
  /// near-black instead.
  static const onLime = Color(0xFF0A0B07);

  static const black = Color(0xFF000000);
  static const ink = Color(0xFF111318);

  // Dark surfaces, cool-biased so they read as "black" beside the lime rather
  // than as muddy grey.
  static const darkGround = Color(0xFF07080C);
  static const darkSurface = Color(0xFF12141B);
  static const darkElevated = Color(0xFF1B1E27);
  static const darkLine = Color(0xFF2A2E3A);
  static const darkText = Color(0xFFF3F4F7);
  static const darkMuted = Color(0xFF9AA0B0);

  // Light surfaces.
  static const lightGround = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightLine = Color(0xFFE4E6EC);
  static const lightMuted = Color(0xFF5C6070);

  /// Ambient violet from the promo art. Decorative glows only.
  static const glow = Color(0xFF7B3FF2);

  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF2FA84F);
  static const warning = Color(0xFFE0A106);
}

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          secondary: AppColors.lime,
          onSecondary: AppColors.onLime,
          surface: AppColors.lightSurface,
          onSurface: AppColors.ink,
          // Without these two, Flutter falls back to onSurface/surface — every
          // "muted" label would render at full contrast and neutral fills would
          // be invisible against the card behind them.
          onSurfaceVariant: AppColors.lightMuted,
          surfaceContainerHighest: AppColors.lightGround,
          error: AppColors.danger,
          onError: Colors.white,
          outline: AppColors.lightLine,
        ),
        ground: AppColors.lightGround,
        surface: AppColors.lightSurface,
        line: AppColors.lightLine,
        muted: AppColors.lightMuted,
        tokens: AppTokens.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          // In the dark the lime *is* the brand — it carries every action.
          primary: AppColors.lime,
          onPrimary: AppColors.onLime,
          secondary: AppColors.limeBright,
          onSecondary: AppColors.onLime,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText,
          onSurfaceVariant: AppColors.darkMuted,
          surfaceContainerHighest: AppColors.darkElevated,
          error: AppColors.danger,
          onError: Colors.white,
          outline: AppColors.darkLine,
        ),
        ground: AppColors.darkGround,
        surface: AppColors.darkSurface,
        line: AppColors.darkLine,
        muted: AppColors.darkMuted,
        tokens: AppTokens.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color ground,
    required Color surface,
    required Color line,
    required Color muted,
    required AppTokens tokens,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      colorScheme: scheme,
      extensions: [tokens],
      // copyWith(colorScheme:) does NOT recompute the legacy colour slots, so
      // anything still reading `theme.primaryColor` would keep painting the
      // Material baseline purple. Pin them to the scheme so old and new APIs
      // agree — cheaper than hunting every last legacy reference.
      primaryColor: scheme.primary,
      primaryColorDark: isDark ? AppColors.limeDeep : AppColors.black,
      indicatorColor: scheme.primary,
      scaffoldBackgroundColor: ground,
      canvasColor: ground,
      textTheme: text,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? ground : surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkElevated : surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isDark ? BorderSide(color: line) : BorderSide.none,
        ),
      ),

      // The primary CTA is lime in BOTH themes now, which is how the deck
      // draws it. That is safe where a plain accent would not be, because a
      // fill is judged by what sits on it: near-black on lime is 13.8:1. It is
      // deliberately not `scheme.primary`, which stays `ink` in light so the
      // many widgets reading it for *text* keep working.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accentFill,
          foregroundColor: tokens.onAccentFill,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accentFill,
          foregroundColor: tokens.onAccentFill,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: line),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accentInk,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : surface,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : surface,
        selectedItemColor: tokens.accentInk,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightGround,
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: scheme.onSurface),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : surface,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tokens.accentInk,
        textColor: scheme.onSurface,
      ),

      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: scheme.primary),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.primary : muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.accentInk,
        unselectedLabelColor: muted,
        indicatorColor: tokens.accentInk,
      ),
    );
  }
}

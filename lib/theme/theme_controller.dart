import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark preference and persists it across launches.
///
/// Mirrors [LocaleController]: `ThemeMode.system` means "follow the device",
/// anything else is an explicit override. `MaterialApp` listens to this so a
/// change repaints immediately rather than at the next launch.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Read the saved choice. Call once during startup, before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = _decode(prefs.getString(_prefsKey));
    } catch (_) {
      // Missing or unreadable prefs just means "follow the system".
    }
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == ThemeMode.system) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, value.name);
      }
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

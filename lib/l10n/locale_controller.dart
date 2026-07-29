import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's chosen language and persists it across launches.
///
/// `value == null` means "follow the system language"; otherwise it's an
/// explicit override. The app listens to this notifier so a change re-renders
/// `MaterialApp` with the new locale immediately.
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'app_locale';

  /// Languages the app ships translations for.
  static const supportedLocales = <Locale>[Locale('en'), Locale('fr')];

  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// Read the saved choice. Call once during startup, before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && code.isNotEmpty) {
        locale.value = Locale(code);
      }
    } catch (_) {
      // Missing/broken prefs just means "follow the system" — never fatal.
    }
  }

  /// Set (or clear, with null) the language and remember it.
  Future<void> setLocale(Locale? value) async {
    locale.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, value.languageCode);
      }
    } catch (_) {
      // Persisting is best-effort; the in-memory choice still applies now.
    }
  }
}

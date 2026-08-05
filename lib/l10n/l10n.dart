// Localization barrel + ergonomic accessor.
//
// Screens do `import '../l10n/l10n.dart';` then read strings via
// `context.l10n.someKey`, which is shorter and less error-prone than
// `AppLocalizations.of(context).someKey` everywhere.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';
import 'locale_controller.dart';

export 'gen/app_localizations.dart';
export 'locale_controller.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Strings for code that has no `BuildContext` — the API client, background
/// work. Prefer `context.l10n` wherever a context exists; this is for the
/// places that genuinely have none and would otherwise emit raw English.
///
/// Resolves the same way `MaterialApp` does: an explicit choice wins, then the
/// device's language, then the first supported locale.
AppLocalizations get l10nNow {
  final want = LocaleController.instance.locale.value ??
      PlatformDispatcher.instance.locale;
  final supported = LocaleController.supportedLocales
      .any((l) => l.languageCode == want.languageCode);
  return lookupAppLocalizations(
    supported ? Locale(want.languageCode) : LocaleController.supportedLocales.first,
  );
}

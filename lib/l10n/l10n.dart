// Localization barrel + ergonomic accessor.
//
// Screens do `import '../l10n/l10n.dart';` then read strings via
// `context.l10n.someKey`, which is shorter and less error-prone than
// `AppLocalizations.of(context).someKey` everywhere.
import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';
export 'locale_controller.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

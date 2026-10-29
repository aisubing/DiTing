/// Single entry point for localized text: `import 'package:diting/app/l10n/l10n.dart';`
/// then `context.l10n.someKey`.
///
/// The strings themselves live in `lib/l10n/app_<locale>.arb` and are compiled into
/// [AppL10n] by `flutter gen-l10n` (see `l10n.yaml`). Adding a language is only a new ARB
/// file plus one entry in [AppLanguageMode].
library;

import 'package:diting/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:diting/l10n/app_localizations.dart';

extension AppL10nContext on BuildContext {
  /// Shorthand for `AppL10n.of(context)`; the delegate is registered by the app root.
  AppL10n get l10n => AppL10n.of(this);
}

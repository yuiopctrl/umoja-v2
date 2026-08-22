import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Shorthand for the generated localizations lookup: `context.l10n.foo`
/// instead of `AppLocalizations.of(context)!.foo`. The `!` is safe here
/// — `AppLocalizations` is always installed app-wide (see `app.dart`),
/// so every widget in the tree has one.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

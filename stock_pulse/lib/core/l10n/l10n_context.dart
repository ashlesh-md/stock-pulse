import 'package:flutter/widgets.dart';

import 'package:stock_pulse/core/l10n/app_strings.dart';

extension L10nX on BuildContext {
  /// Strings of the nearest `Localizations`; the default locale's when the
  /// app has no `AppStringsDelegate` (widget tests of single widgets).
  AppStrings get strings =>
      Localizations.of<AppStrings>(this, AppStrings) ??
      appStringsFor(Localizations.maybeLocaleOf(this) ?? defaultLocale);
}

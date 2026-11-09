import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:stock_pulse/core/l10n/app_strings.dart';

/// Loads [AppStrings] for `MaterialApp.localizationsDelegates`.
class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(appStringsFor(locale));

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

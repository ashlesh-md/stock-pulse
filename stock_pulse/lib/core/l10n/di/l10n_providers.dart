import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/l10n/app_strings.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// The app's locale: the device locale until Settings picks one.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => PlatformDispatcher.instance.locale;

  void set(Locale locale) => state = locale;
}

/// Strings for code without a `BuildContext` (controllers building
/// feedback messages). Same source as `context.strings`.
final stringsProvider = Provider<AppStrings>(
  (ref) => appStringsFor(ref.watch(localeProvider)),
);

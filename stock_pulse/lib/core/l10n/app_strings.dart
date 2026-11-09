import 'dart:ui';

import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/core/l10n/strings/alerts_strings.dart';
import 'package:stock_pulse/core/l10n/strings/chat_strings.dart';
import 'package:stock_pulse/core/l10n/strings/common_strings.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';
import 'package:stock_pulse/core/l10n/strings/more_strings.dart';
import 'package:stock_pulse/core/l10n/strings/options_strings.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/core/l10n/strings/portfolio_strings.dart';
import 'package:stock_pulse/core/l10n/strings/shell_strings.dart';
import 'package:stock_pulse/core/l10n/strings/strategy_strings.dart';
import 'package:stock_pulse/core/l10n/strings/studies_strings.dart';

/// Every user-facing string, one getter per area. A locale implements all
/// areas, so a missing translation does not compile.
abstract interface class AppStrings {
  OptionsStrings get options;
  AlertsStrings get alerts;
  StudiesStrings get studies;
  StrategyStrings get strategy;
  ChatStrings get chat;
  CommonStrings get common;
  MarketStrings get market;
  OrderStrings get orders;
  PortfolioStrings get portfolio;
  ErrorStrings get errors;
  ShellStrings get shell;
  MoreStrings get more;
}

const defaultLocale = Locale('en', 'IN');
const supportedLocales = [defaultLocale];

/// Strings for [locale]; unknown languages fall back to English.
AppStrings appStringsFor(Locale locale) => switch (locale.languageCode) {
  _ => const AppStringsEn(),
};

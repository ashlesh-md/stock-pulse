import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/locales/en/common_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/error_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/more_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/order_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/portfolio_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/en/shell_strings_en.dart';
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

final class AppStringsEn implements AppStrings {
  const AppStringsEn();
  @override
  OptionsStrings get options => const OptionsStrings();
  @override
  AlertsStrings get alerts => const AlertsStrings();

  @override
  StudiesStrings get studies => const StudiesStrings();

  @override
  StrategyStrings get strategy => const StrategyStrings();

  @override
  ChatStrings get chat => const ChatStrings();

  @override
  CommonStrings get common => const CommonStringsEn();
  @override
  MarketStrings get market => const MarketStringsEn();
  @override
  OrderStrings get orders => const OrderStringsEn();
  @override
  PortfolioStrings get portfolio => const PortfolioStringsEn();
  @override
  ErrorStrings get errors => const ErrorStringsEn();
  @override
  ShellStrings get shell => const ShellStringsEn();
  @override
  MoreStrings get more => const MoreStringsEn();
}

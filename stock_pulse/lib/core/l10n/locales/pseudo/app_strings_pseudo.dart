import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/alerts_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/chart_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/chat_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/common_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/error_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/market_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/more_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/options_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/order_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/portfolio_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/shell_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/strategy_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/studies_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/strings/alerts_strings.dart';
import 'package:stock_pulse/core/l10n/strings/chart_strings.dart';
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

/// Debug-only pseudo-locale for layout checks: the English text, longer
/// and accented.
final class AppStringsPseudo implements AppStrings {
  const AppStringsPseudo();

  @override
  ChartStrings get chart => const ChartStringsPseudo();
  @override
  OptionsStrings get options => const OptionsStringsPseudo();
  @override
  AlertsStrings get alerts => const AlertsStringsPseudo();
  @override
  StudiesStrings get studies => const StudiesStringsPseudo();
  @override
  StrategyStrings get strategy => const StrategyStringsPseudo();
  @override
  ChatStrings get chat => const ChatStringsPseudo();
  @override
  CommonStrings get common => const CommonStringsPseudo();
  @override
  MarketStrings get market => const MarketStringsPseudo();
  @override
  OrderStrings get orders => const OrderStringsPseudo();
  @override
  PortfolioStrings get portfolio => const PortfolioStringsPseudo();
  @override
  ErrorStrings get errors => const ErrorStringsPseudo();
  @override
  ShellStrings get shell => const ShellStringsPseudo();
  @override
  MoreStrings get more => const MoreStringsPseudo();
}

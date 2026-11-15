import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/strategy_strings.dart';

final class StrategyStringsPseudo extends StrategyStrings {
  const StrategyStringsPseudo();

  @override
  String get empty => pseudo(super.empty);
  @override
  String get openChain => pseudo(super.openChain);
  @override
  String get failed => pseudo(super.failed);
  @override
  String get preview => pseudo(super.preview);
  @override
  String get todayUnavailable => pseudo(super.todayUnavailable);
  @override
  String get unlimited => pseudo(super.unlimited);
  @override
  String maxProfitValue(String amount) => pseudo(super.maxProfitValue(amount));
  @override
  String maxLossValue(String amount) => pseudo(super.maxLossValue(amount));
  @override
  String breakevensValue(List<String> prices) =>
      pseudo(super.breakevensValue(prices));
  @override
  String netPremiumValue(String amount) =>
      pseudo(super.netPremiumValue(amount));
  @override
  String get trade => pseudo(super.trade);
  @override
  String get remove => pseudo(super.remove);
  @override
  String get chart => pseudo(super.chart);
  @override
  String legs(int count) => pseudo(super.legs(count));
  @override
  String crosshair(String spot, String value) =>
      pseudo(super.crosshair(spot, value));
}

import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/alerts_strings.dart';

final class AlertsStringsPseudo extends AlertsStrings {
  const AlertsStringsPseudo();

  @override
  String get dismiss => pseudo(super.dismiss);
  @override
  String get view => pseudo(super.view);
  @override
  String conditionPrice(String condition, String price) =>
      pseudo(super.conditionPrice(condition, price));
  @override
  String get title => pseudo(super.title);
  @override
  String get triggeredAlert => pseudo(super.triggeredAlert);
  @override
  String get empty => pseudo(super.empty);
  @override
  String get create => pseudo(super.create);
  @override
  String get symbol => pseudo(super.symbol);
  @override
  String get level => pseudo(super.level);
  @override
  String get condition => pseudo(super.condition);
  @override
  String get above => pseudo(super.above);
  @override
  String get below => pseudo(super.below);
  @override
  String get invalid => pseudo(super.invalid);
  @override
  String get failed => pseudo(super.failed);
  @override
  String get cancel => pseudo(super.cancel);
  @override
  String triggered(String symbol, String price) =>
      pseudo(super.triggered(symbol, price));
}

import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/chart_strings.dart';

final class ChartStringsPseudo extends ChartStrings {
  const ChartStringsPseudo();

  @override
  String get draw => pseudo(super.draw);
  @override
  String get horizontal => pseudo(super.horizontal);
  @override
  String get trend => pseudo(super.trend);
  @override
  String get fibonacci => pseudo(super.fibonacci);
  @override
  String get cancel => pseudo(super.cancel);
  @override
  String get delete => pseudo(super.delete);
  @override
  String get limit => pseudo(super.limit);
  @override
  String get saveFailed => pseudo(super.saveFailed);
  @override
  String get expand => pseudo(super.expand);
  @override
  String get exit => pseudo(super.exit);
  @override
  String get settings => pseudo(super.settings);
  @override
  String get logScale => pseudo(super.logScale);
  @override
  String get gridlines => pseudo(super.gridlines);
  @override
  String get empty => pseudo(super.empty);
  @override
  String get setAlert => pseudo(super.setAlert);
  @override
  String get buyLimit => pseudo(super.buyLimit);
  @override
  String get sellLimit => pseudo(super.sellLimit);
}

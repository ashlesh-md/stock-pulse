import 'package:stock_pulse/core/l10n/locales/en/common_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/common_strings.dart';

final class CommonStringsPseudo implements CommonStrings {
  const CommonStringsPseudo();

  static const _en = CommonStringsEn();

  @override
  String get appTitle => pseudo(_en.appTitle);
  @override
  String get retry => pseudo(_en.retry);
  @override
  String get dismiss => pseudo(_en.dismiss);
  @override
  String get loading => pseudo(_en.loading);
  @override
  String get done => pseudo(_en.done);
  @override
  String get linkNotAvailable => pseudo(_en.linkNotAvailable);
  @override
  String get noValue => pseudo(_en.noValue);
  @override
  String get connectionLive => pseudo(_en.connectionLive);
  @override
  String get connectionDelayed => pseudo(_en.connectionDelayed);
  @override
  String get connectionReconnecting => pseudo(_en.connectionReconnecting);
  @override
  String get connectionOffline => pseudo(_en.connectionOffline);
  @override
  String connectionSemantics(String state) =>
      pseudo(_en.connectionSemantics(state));
  @override
  String get phasePreOpen => pseudo(_en.phasePreOpen);
  @override
  String get phaseOpen => pseudo(_en.phaseOpen);
  @override
  String get phaseClosed => pseudo(_en.phaseClosed);
  @override
  String marketSemantics(String phase) => pseudo(_en.marketSemantics(phase));
  @override
  String demoClock(String time) => pseudo(_en.demoClock(time));
  @override
  String demoClockSemantics(String time, String phase) =>
      pseudo(_en.demoClockSemantics(time, phase));
  @override
  String get stale => pseudo(_en.stale);
  @override
  String staleSince(String time) => pseudo(_en.staleSince(time));
  @override
  String get pricesNotLive => pseudo(_en.pricesNotLive);
  @override
  String pricesNotLiveSince(String time) =>
      pseudo(_en.pricesNotLiveSince(time));
  @override
  String get pending => pseudo(_en.pending);
  @override
  String get orderPendingSemantics => pseudo(_en.orderPendingSemantics);
  @override
  String get changeUnavailable => pseudo(_en.changeUnavailable);
  @override
  String get unchanged => pseudo(_en.unchanged);
  @override
  String changeUp(String amount, String percent) =>
      pseudo(_en.changeUp(amount, percent));
  @override
  String changeDown(String amount, String percent) =>
      pseudo(_en.changeDown(amount, percent));
  @override
  String get priceUnavailable => pseudo(_en.priceUnavailable);
  @override
  String priceSemantics(
    String amount, {
    required String direction,
    required bool stale,
  }) => pseudo(_en.priceSemantics(amount, direction: direction, stale: stale));
  @override
  String get priceUp => pseudo(_en.priceUp);
  @override
  String get priceDown => pseudo(_en.priceDown);
  @override
  String get lotsUnit => pseudo(_en.lotsUnit);
  @override
  String lots(int n) => pseudo(_en.lots(n));
  @override
  String stepperValue(int n, String unit) => pseudo(_en.stepperValue(n, unit));
  @override
  String decrease(String unit) => pseudo(_en.decrease(unit));
  @override
  String increase(String unit) => pseudo(_en.increase(unit));
}

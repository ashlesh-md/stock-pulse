import 'package:stock_pulse/core/l10n/plural.dart';
import 'package:stock_pulse/core/l10n/strings/common_strings.dart';

final class CommonStringsEn implements CommonStrings {
  const CommonStringsEn();

  @override
  String get appTitle => 'StockPulse';
  @override
  String get retry => 'Retry';
  @override
  String get dismiss => 'Dismiss';
  @override
  String get loading => 'Loading...';
  @override
  String get done => 'Done';
  @override
  String get linkNotAvailable => 'Link not available';
  @override
  String get noValue => '—';

  @override
  String get connectionLive => 'Live';
  @override
  String get connectionDelayed => 'Delayed';
  @override
  String get connectionReconnecting => 'Reconnecting';
  @override
  String get connectionOffline => 'Offline';
  @override
  String connectionSemantics(String state) => 'Connection $state';

  @override
  String get phasePreOpen => 'Pre-open';
  @override
  String get phaseOpen => 'Open';
  @override
  String get phaseClosed => 'Closed';
  @override
  String marketSemantics(String phase) => 'Market $phase';
  @override
  String demoClock(String time) => 'Demo clock $time';
  @override
  String demoClockSemantics(String time, String phase) =>
      'Demo clock, virtual time $time, market ${phase.toLowerCase()}';

  @override
  String get stale => 'Stale';
  @override
  String staleSince(String time) => 'Stale since $time';
  @override
  String get pricesNotLive => 'Prices not live';
  @override
  String pricesNotLiveSince(String time) => 'Prices not live since $time';

  @override
  String get pending => 'Pending';
  @override
  String get orderPendingSemantics => 'Order pending';

  @override
  String get changeUnavailable => 'Change unavailable';
  @override
  String get unchanged => 'Unchanged';
  @override
  String changeUp(String amount, String percent) =>
      'Up $amount rupees, $percent percent';
  @override
  String changeDown(String amount, String percent) =>
      'Down $amount rupees, $percent percent';

  @override
  String get priceUnavailable => 'Price unavailable';
  @override
  String priceSemantics(
    String amount, {
    required String direction,
    required bool stale,
  }) => 'Price $amount rupees$direction${stale ? ', stale' : ''}';
  @override
  String get priceUp => ', up';
  @override
  String get priceDown => ', down';

  @override
  String get lotsUnit => 'lots';
  @override
  String lots(int n) => plural(n, one: '$n lot', other: '$n lots');
  @override
  String stepperValue(int n, String unit) => '$n $unit';
  @override
  String decrease(String unit) => 'Decrease $unit';
  @override
  String increase(String unit) => 'Increase $unit';
}

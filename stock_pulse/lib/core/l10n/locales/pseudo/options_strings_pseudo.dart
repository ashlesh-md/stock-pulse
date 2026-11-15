import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/options_strings.dart';

final class OptionsStringsPseudo extends OptionsStrings {
  const OptionsStringsPseudo();

  @override
  String get sectionTitle => pseudo(super.sectionTitle);
  @override
  String get chooseUnderlying => pseudo(super.chooseUnderlying);
  @override
  String get chooseUnderlyingHint => pseudo(super.chooseUnderlyingHint);
  @override
  String get chooseUnderlyingAction => pseudo(super.chooseUnderlyingAction);
  @override
  String title(String underlying) => pseudo(super.title(underlying));
  @override
  String get call => pseudo(super.call);
  @override
  String get put => pseudo(super.put);
  @override
  String get calls => pseudo(super.calls);
  @override
  String get puts => pseudo(super.puts);
  @override
  String get strikeHeader => pseudo(super.strikeHeader);
  @override
  String get oi => pseudo(super.oi);
  @override
  String get oiChange => pseudo(super.oiChange);
  @override
  String get ltp => pseudo(super.ltp);
  @override
  String get iv => pseudo(super.iv);
  @override
  String get delta => pseudo(super.delta);
  @override
  String get greeks => pseudo(super.greeks);
  @override
  String get gamma => pseudo(super.gamma);
  @override
  String get theta => pseudo(super.theta);
  @override
  String get vega => pseudo(super.vega);
  @override
  String get greeksUnavailable => pseudo(super.greeksUnavailable);
  @override
  String greekValue(String label, String value) =>
      pseudo(super.greekValue(label, value));
  @override
  String get columns => pseudo(super.columns);
  @override
  String get alwaysShown => pseudo(super.alwaysShown);
  @override
  String get atm => pseudo(super.atm);
  @override
  String get backToAtm => pseudo(super.backToAtm);
  @override
  String get addToStrategy => pseudo(super.addToStrategy);
  @override
  String get strategyAdded => pseudo(super.strategyAdded);
  @override
  String get viewStrategy => pseudo(super.viewStrategy);
  @override
  String get strategyFull => pseudo(super.strategyFull);
  @override
  String get startNew => pseudo(super.startNew);
  @override
  String strategyOtherChain(String chain) =>
      pseudo(super.strategyOtherChain(chain));
  @override
  String get weekly => pseudo(super.weekly);
  @override
  String get monthly => pseudo(super.monthly);
  @override
  String get expiresToday => pseudo(super.expiresToday);
  @override
  String get empty => pseudo(super.empty);
  @override
  String expiredNotice(String oldExpiry, String newExpiry) =>
      pseudo(super.expiredNotice(oldExpiry, newExpiry));
  @override
  String spot(String underlying, String price) =>
      pseudo(super.spot(underlying, price));
  @override
  String cellSemantics(String side, int strike, String ltp, String oi) =>
      pseudo(super.cellSemantics(side, strike, ltp, oi));
  @override
  String details(int oi, double? iv, double? delta) =>
      pseudo(super.details(oi, iv, delta));
}

import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/studies_strings.dart';

final class StudiesStringsPseudo extends StudiesStrings {
  const StudiesStringsPseudo();

  @override
  String get undo => pseudo(super.undo);
  @override
  String get removed => pseudo(super.removed);
  @override
  String get title => pseudo(super.title);
  @override
  String get limit => pseudo(super.limit);
  @override
  String get paneLimit => pseudo(super.paneLimit);
  @override
  String get add => pseudo(super.add);
  @override
  String periodValue(int period) => pseudo(super.periodValue(period));
  @override
  String get intradayOnly => pseudo(super.intradayOnly);
  @override
  String get remove => pseudo(super.remove);
  @override
  String notEnough(String name) => pseudo(super.notEnough(name));
  @override
  String name(String kind) => pseudo(super.name(kind));
}

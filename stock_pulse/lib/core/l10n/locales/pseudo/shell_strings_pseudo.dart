import 'package:stock_pulse/core/l10n/locales/en/shell_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/shell_strings.dart';

final class ShellStringsPseudo implements ShellStrings {
  const ShellStringsPseudo();

  static const _en = ShellStringsEn();

  @override
  String get watchlist => pseudo(_en.watchlist);
  @override
  String get options => pseudo(_en.options);
  @override
  String get ai => pseudo(_en.ai);
  @override
  String get portfolio => pseudo(_en.portfolio);
  @override
  String get more => pseudo(_en.more);
  @override
  String get tabs => pseudo(_en.tabs);
  @override
  String get selectStock => pseudo(_en.selectStock);
}

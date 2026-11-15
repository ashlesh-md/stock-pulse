import 'package:stock_pulse/core/l10n/locales/en/error_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';

final class ErrorStringsPseudo implements ErrorStrings {
  const ErrorStringsPseudo();

  static const _en = ErrorStringsEn();

  @override
  String get title => pseudo(_en.title);
  @override
  String get network => pseudo(_en.network);
  @override
  String get server => pseudo(_en.server);
  @override
  String get parse => pseudo(_en.parse);
  @override
  String get outdated => pseudo(_en.outdated);
  @override
  String get unknown => pseudo(_en.unknown);
  @override
  String get sessionExpired => pseudo(_en.sessionExpired);
  @override
  String get restartDemo => pseudo(_en.restartDemo);
  @override
  String get serverHint => pseudo(_en.serverHint);
}

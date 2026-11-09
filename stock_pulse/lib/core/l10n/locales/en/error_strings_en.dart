import 'package:stock_pulse/core/l10n/strings/error_strings.dart';

final class ErrorStringsEn implements ErrorStrings {
  const ErrorStringsEn();

  @override
  String get title => 'Something went wrong';
  @override
  String get network => 'Cannot reach the server. Check your connection.';
  @override
  String get server => 'The server could not do that. Try again.';
  @override
  String get parse => 'The server sent something unexpected.';
  @override
  String get outdated =>
      'Server out of date: it does not know this request. '
      'Restart market_server on the current code.';
  @override
  String get unknown => 'Something went wrong. Try again.';
  @override
  String get serverHint =>
      'Is the server running? cd market_server && dart run bin/server.dart';
}

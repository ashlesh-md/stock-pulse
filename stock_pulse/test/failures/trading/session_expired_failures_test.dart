import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/l10n/locales/en/error_strings_en.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';

void main() {
  const strings = ErrorStringsEn();

  test('F4 a 401 reads as an expired demo session, never a raw code', () {
    const error = ServerError(401, 'unauthorized', 'Send Authorization');
    expect(errorText(strings, error), 'Demo session expired.');
    expect(errorText(strings, error), isNot(contains('401')));
    expect(
      errorText(strings, const ServerError(422, 'invalid', 'bad qty')),
      strings.server,
    );
  });

  testWidgets('F4 a 401 offers Restart demo instead of Retry', (tester) async {
    var restarts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ErrorView(
            error: const ServerError(401, 'unauthorized', 'token'),
            onRetry: () => restarts++,
          ),
        ),
      ),
    );

    expect(find.text('Demo session expired.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Restart demo'));
    expect(restarts, 1);
  });

  testWidgets('F4 other failures keep Retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ErrorView(error: const NetworkError(), onRetry: () {}),
        ),
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Restart demo'), findsNothing);
  });
}

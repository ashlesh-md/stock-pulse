import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/assets/app_images.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/app_strings_delegate.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/core/l10n/plural.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';

void main() {
  group('appStringsFor (ADR-0018)', () {
    test('English for en_IN and for unknown languages', () {
      expect(appStringsFor(defaultLocale), isA<AppStringsEn>());
      expect(appStringsFor(const Locale('xx')), isA<AppStringsEn>());
      expect(supportedLocales, [defaultLocale]);
    });
  });

  group('AppStringsDelegate', () {
    test('supports any locale, loads synchronously, never reloads', () async {
      const delegate = AppStringsDelegate();
      expect(delegate.isSupported(const Locale('hi')), isTrue);
      expect(await delegate.load(defaultLocale), isA<AppStringsEn>());
      expect(delegate.shouldReload(const AppStringsDelegate()), isFalse);
    });

    testWidgets('context.strings reads the delegate', (tester) async {
      late AppStrings found;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppStringsDelegate(),
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              found = context.strings;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found.market.watchlistTitle, 'Watchlist');
    });

    testWidgets('context.strings falls back to English without a delegate', (
      tester,
    ) async {
      late AppStrings found;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = context.strings;
            return const SizedBox();
          },
        ),
      );
      expect(found, isA<AppStringsEn>());
    });
  });

  group('stringsProvider', () {
    test('follows localeProvider', () {
      final container = ProviderContainer.test();
      expect(container.read(stringsProvider), isA<AppStringsEn>());
      container.read(localeProvider.notifier).set(const Locale('hi', 'IN'));
      expect(container.read(localeProvider), const Locale('hi', 'IN'));
      expect(container.read(stringsProvider), isA<AppStringsEn>());
    });
  });

  test('FR-161: plural picks one or other', () {
    expect(plural(1, one: '1 lot', other: 'n lots'), '1 lot');
    expect(plural(3, one: '1 lot', other: '3 lots'), '3 lots');
    expect(plural(0, zero: 'none', one: '1', other: 'n'), 'none');
    expect(const AppStringsEn().common.lots(2), '2 lots');
  });

  test('errorText maps each AppError kind, never its message', () {
    final s = const AppStringsEn().errors;
    expect(errorText(s, const NetworkError('raw')), s.network);
    expect(errorText(s, const ServerError(500, 'x', 'raw')), s.server);
    expect(errorText(s, const ParseError('raw')), s.parse);
    expect(errorText(s, StateError('raw')), s.unknown);
  });

  test('errorText names an out-of-date server when an endpoint is missing', () {
    final s = const AppStringsEn().errors;
    expect(
      errorText(s, const ServerError(404, 'not_found', 'raw')),
      s.outdated,
    );
    expect(s.outdated, contains('out of date'));
  });

  test('every AppImages path exists on disk', () {
    for (final path in AppImages.all) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every AppStrings area resolves a non-empty representative key', () {
    const strings = AppStringsEn();
    final values = [
      strings.options.title('NIFTY'),
      strings.alerts.title,
      strings.studies.title,
      strings.strategy.chart,
      strings.chat.title,
      strings.common.noValue,
      strings.market.watchlistTitle,
      strings.orders.buy,
      strings.portfolio.title,
      strings.errors.network,
      strings.shell.watchlist,
      strings.more.title,
    ];
    expect(values, hasLength(12));
    expect(values.every((value) => value.trim().isNotEmpty), isTrue);
  });
}

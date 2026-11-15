import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/app_strings_delegate.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/app_strings_pseudo.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';

void main() {
  group('pseudo text', () {
    test('accents every ASCII letter and keeps digits and symbols', () {
      expect(pseudo('Buy 2 @ ₹10'), startsWith('[Ɓûý 2 @ ₹10'));
    });

    test('grows text by about 40 % inside brackets', () {
      const english = 'Funds available for trading';

      final text = pseudo(english);

      expect(text, startsWith('['));
      expect(text, endsWith(']'));
      expect(text.length / english.length, inInclusiveRange(1.35, 1.45));
    });

    test('keeps short text short and empty text empty', () {
      expect(pseudo('OI'), '[ÖÎ]');
      expect(pseudo(''), '');
    });
  });

  group('FR-164 pseudo-locale', () {
    test('en_XA loads pseudo strings in debug builds', () async {
      expect(supportedLocales, contains(pseudoLocale));
      expect(appStringsFor(pseudoLocale), isA<AppStringsPseudo>());
      expect(
        await const AppStringsDelegate().load(pseudoLocale),
        isA<AppStringsPseudo>(),
      );
    });

    test('every area reads its English text in pseudo form', () {
      const en = AppStringsEn();
      const xa = AppStringsPseudo();

      expect(xa.market.watchlistTitle, pseudo(en.market.watchlistTitle));
      expect(
        xa.orders.ticketTitle('TCS'),
        pseudo(en.orders.ticketTitle('TCS')),
      );
      expect(xa.options.title('NIFTY'), pseudo(en.options.title('NIFTY')));
      expect(xa.portfolio.ltp('10'), pseudo(en.portfolio.ltp('10')));
      expect(xa.chat.emptyTitle, pseudo(en.chat.emptyTitle));
      expect(xa.more.connecting(2), pseudo(en.more.connecting(2)));
      expect(xa.common.retry, pseudo(en.common.retry));
      expect(xa.errors.network, pseudo(en.errors.network));
    });

    test('a key the pseudo-locale leaves out falls back to English', () {
      expect(
        const AppStringsPseudo().chat.suggestions,
        const AppStringsEn().chat.suggestions,
      );
    });

    test('other languages and regions still fall back to English', () {
      expect(appStringsFor(const Locale('hi', 'IN')), isA<AppStringsEn>());
      expect(appStringsFor(const Locale('en', 'US')), isA<AppStringsEn>());
    });
  });
}

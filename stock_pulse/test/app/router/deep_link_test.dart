import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/deep_link.dart';

void main() {
  test('custom and verified-domain links normalize to safe app locations', () {
    expect(
      normaliseLink(Uri.parse('stockpulse://app/stock/M%26M')).toString(),
      '/stock/M%26M',
    );
    expect(
      normaliseLink(
        Uri.parse(
          'https://stockpulse.example.com/options?u=NIFTY&e=2026-11-10&price=1',
        ),
      ).toString(),
      '/options?u=NIFTY&e=2026-11-10',
    );
  });

  test('a trade link resolves to a guarded prefilled ticket', () {
    expect(
      normaliseLink(
        Uri.parse(
          'stockpulse://app/trade/RELIANCE?side=buy&type=limit&price=1500',
        ),
      )?.toString(),
      '/order/RELIANCE?side=buy&price=1500.0&source=deeplink',
    );
    expect(
      normaliseLink(
        Uri.parse('stockpulse://app/trade/RELIANCE?side=buy&type=limit'),
      ),
      isNull,
    );
    for (final query in [
      'side=hold',
      'side=buy&type=stop',
      'side=sell&type=limit&price=0',
      'side=sell&type=limit&price=NaN',
      'side=sell&type=market&price=1',
    ]) {
      expect(
        normaliseLink(Uri.parse('stockpulse://app/trade/RELIANCE?$query')),
        isNull,
        reason: query,
      );
    }
    expect(
      normaliseLink(Uri.parse('stockpulse://app/trade/RELIANCE?side=buy'))
          ?.path,
      '/order/RELIANCE',
    );
    expect(
      normaliseLink(
        Uri.parse(
          'stockpulse://app/trade/RELIANCE?side=buy&type=market&price=1',
        ),
      ),
      isNull,
    );
  });
  test(
    'external order actions, developer links and unknown hosts are refused',
    () {
      for (final value in [
        'stockpulse://evil/stock/TCS',
        'https://evil.test/stock/TCS',
        'stockpulse://app/more/clock',
        'stockpulse://app/order/TCS?side=buy',
        'stockpulse://app/strategy',
        'javascript:alert(1)',
      ]) {
        expect(normaliseLink(Uri.parse(value)), isNull, reason: value);
      }
    },
  );
}

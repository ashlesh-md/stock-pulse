import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

void main() {
  test('lot size comes from the JSON, never a constant (S-6 AC2)', () {
    final i = Instrument.fromJson(const {
      'id': 'NIFTY-261117-24500-CE',
      'name': 'NIFTY 24500 CE',
      'kind': 'option',
      'lotSize': 50,
      'tickSize': 0.05,
      'bandLow': 0.05,
      'bandHigh': 300.0,
      'underlying': 'NIFTY',
      'expiry': '2026-11-17',
      'strike': 24500,
      'right': 'CE',
    });
    expect(i.lotSize, 50);
    expect(i.kind, InstrumentKind.option);
    expect(i.id, 'NIFTY-261117-24500-CE');
    expect(i.underlying, 'NIFTY');
    expect(i.strike, 24500);
    expect(i.right, OptionRight.ce);
    expect(i.bandLow, 0.05);
    expect(i.bandHigh, 300.0);
  });

  test('server equity and index JSON parse with band and strike step', () {
    final reliance = Instrument.fromJson(const {
      'id': 'RELIANCE',
      'symbol': 'RELIANCE',
      'name': 'Reliance Industries',
      'exchange': 'NSE',
      'sector': 'Energy',
      'kind': 'equity',
      'tickSize': 0.05,
      'lotSize': 1,
      'bandLow': 1129.9,
      'bandHigh': 1694.8,
      'strikeStep': 10,
    });
    expect(reliance.kind, InstrumentKind.equity);
    expect(reliance.bandLow, 1129.9);
    expect(reliance.strikeStep, 10);

    final nifty = Instrument.fromJson(const {
      'id': 'NIFTY',
      'name': 'Nifty 50',
      'kind': 'index',
      'tickSize': 0.05,
      'lotSize': 1,
      'strikeStep': 50,
    });
    expect(nifty.kind, InstrumentKind.marketIndex);
    expect(nifty.bandLow, isNull);
  });

  test('a v1 payload without kind is an equity', () {
    final i = Instrument.fromJson(const {
      'symbol': 'TCS',
      'name': 'Tata Consultancy Services',
      'exchange': 'NSE',
      'sector': 'IT',
      'tickSize': 0.05,
      'lotSize': 1,
    });
    expect(i.kind, InstrumentKind.equity);
    expect(i.id, 'TCS');
  });
}

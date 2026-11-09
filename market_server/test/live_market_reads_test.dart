import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:market_server/src/live_market_reads.dart';
import 'package:market_server/src/option_book.dart';
import 'package:test/test.dart';

class _FixedOptionBook extends OptionBook {
  _FixedOptionBook(super.engine, super.clock, super.calendar);

  static const expiry = '2026-11-11';
  static final rows = [_row(1400, 1000, 0), _row(1410, 0, 0), _row(1420, 0, 1)];

  @override
  List<Map<String, Object?>> expiries(String underlying) => [
    {'code': expiry},
  ];

  @override
  Map<String, Object?> chain(
    String underlying,
    String expiry, {
    int? from,
    int? to,
  }) => {'spot': 1410.0, 'atm': 1410, 'rows': rows};
}

Map<String, Object?> _row(int strike, int callOi, int putOi) => {
  'strike': strike,
  'ce': _cell('CE-$strike', callOi),
  'pe': _cell('PE-$strike', putOi),
};

Map<String, Object?> _cell(String id, int oi) => {
  'contractId': id,
  'ltp': 1.0,
  'oi': oi,
  'iv': 18.0,
};

void main() {
  test(
    'chain analytics use all strikes and the real option lot size',
    () async {
      const today = IstDate(2026, 11, 10);
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11, 10, 5),
        marketStart: Ist.at(today, 10, 0),
      );
      final calendar = MarketCalendar(
        holidays: const {},
        holidaySourceDate: 'test',
      );
      final engine = MarketEngine(
        [
          const Instrument(
            symbol: 'RELIANCE',
            name: 'Reliance Industries',
            exchange: 'NSE',
            sector: 'Energy',
            basePrice: 1410,
            strikeStep: 10,
          ),
        ],
        random: Random(1),
        marketClock: clock,
        calendar: calendar,
        intradayDays: 1,
        dailyDays: 2,
      );
      addTearDown(engine.stop);
      final options = _FixedOptionBook(engine, clock, calendar);
      final reads = LiveMarketReads(engine, options, clock);

      final chain = reads.chainSnapshot(
        'RELIANCE',
        expiry: _FixedOptionBook.expiry,
        around: 0,
      )!;

      expect(chain.rows.map((row) => row.strike), [1410]);
      expect(chain.pcr, 0.001);
      expect(chain.maxPain, 1400);
      expect(chain.maxCallOiStrike, 1400);
      expect(chain.maxPutOiStrike, 1420);
      expect(chain.strikeStep, 10);
      expect(chain.lotSize, 500);
      expect(() => chain.rows.add(chain.rows.single), throwsUnsupportedError);
      expect(() => reads.instruments().clear(), throwsUnsupportedError);
      final source = engine.candles('RELIANCE', const Duration(days: 1)).first;
      final snapshot = reads.candles('RELIANCE', const Duration(days: 1)).first;
      expect(snapshot, isNot(same(source)));
    },
  );
}

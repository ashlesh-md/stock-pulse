import 'dart:math';

import 'package:market_server/src/broker.dart';
import 'package:market_server/src/ist.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/models.dart';
import 'package:market_server/src/open_interest.dart';
import 'package:option_math/option_math.dart';

class OptionBook {
  OptionBook(this.engine, this.clock, this.calendar, {Random? random})
    : openInterest = OpenInterest(random: random) {
    engine.afterEquities = (changed, now) {
      if (engine.phase != MarketPhase.open) return;
      openInterest.step();
      final previous = {
        for (final stock in engine.stocks)
          if (stock.instrument.kind == InstrumentKind.option)
            stock.id: stock.ltp,
      };
      for (final id in _strikes.keys.toList()) {
        final parts = id.split(':');
        chain(parts[0], parts[1]);
      }
      for (final stock in engine.stocks) {
        if (stock.instrument.kind == InstrumentKind.option &&
            (engine.load || previous[stock.id] != stock.ltp)) {
          changed.add(stock.id);
        }
      }
    };
  }
  final MarketEngine engine;
  final MarketClock clock;
  final MarketCalendar calendar;
  final OpenInterest openInterest;
  final _strikes = <String, List<int>>{};

  List<Map<String, Object?>> expiries(String underlying) {
    final stock = engine[underlying];
    if (stock?.instrument.strikeStep == null) {
      throw const OrderRejection(
        'unknown_underlying',
        'No option chain for this instrument',
        status: 404,
      );
    }
    final today = Ist.dateOf(clock.marketNow());
    final result = [
      for (final expiry in calendar.expiriesFor(underlying, today, count: 5))
        if (expiry.expiryAt.isAfter(clock.marketNow()))
          <String, Object?>{
            'code': expiry.code,
            'expiryAt': expiry.expiryAt.millisecondsSinceEpoch,
            'kind': expiry.kind.name,
            'isToday': expiry.date == today,
          },
    ].take(4).toList();
    return result;
  }

  Map<String, Object?> chain(
    String underlying,
    String expiry, {
    int? from,
    int? to,
  }) {
    final spot = engine[underlying];
    if (spot?.instrument.strikeStep == null) {
      throw const OrderRejection(
        'unknown_underlying',
        'Unknown option underlying',
        status: 404,
      );
    }
    final key = '$underlying:$expiry';
    if (!_strikes.containsKey(key) &&
        !expiries(underlying).any((e) => e['code'] == expiry)) {
      throw const OrderRejection(
        'unknown_expiry',
        'Expiry is not listed',
        status: 404,
      );
    }
    final step = spot!.instrument.strikeStep!;
    final strikes = _strikes.putIfAbsent(key, () {
      final center = (spot.prevClose / step).round() * step;
      return [for (var n = -20; n <= 20; n++) center + n * step];
    });
    final at = DateTime.parse('${expiry}T10:00:00Z');
    final years = yearsToExpiry(clock.marketNow(), at);
    final rows = <Map<String, Object?>>[];
    for (final strike in strikes) {
      final cells = <String, Object?>{'strike': strike};
      for (final right in OptionRight.values) {
        final dateCode = expiry.replaceAll('-', '').substring(2);
        final id = '$underlying-$dateCode-$strike-${right.name.toUpperCase()}';
        final price = max(
          .05,
          (bsPrice(
                        right: right,
                        spot: spot.ltp,
                        strike: strike.toDouble(),
                        years: years,
                        iv: .18,
                      ) *
                      20)
                  .round() /
              20,
        );
        engine.ensureOption(
          Instrument(
            symbol: id,
            name: id,
            exchange: 'NFO',
            sector: 'Options',
            basePrice: price,
            lotSize: underlying == 'NIFTY' ? 65 : 1,
            kind: InstrumentKind.option,
            bandPct: null,
            underlying: underlying,
            expiry: expiry,
            strike: strike,
            right: right,
          ),
        );
        openInterest.list(
          id,
          lot: underlying == 'NIFTY' ? 65 : 1,
          strike: strike,
          spot: spot.prevClose,
          step: step,
          right: right,
        );
        if (engine.phase == MarketPhase.open) {
          engine.repriceOption(id, price, clock.marketNow());
        }
        if ((from == null || strike >= from) && (to == null || strike <= to)) {
          cells[right.name] = {
            'contractId': id,
            'ltp': engine[id]!.ltp,
            'change': engine[id]!.ltp - engine[id]!.prevClose,
            'oi': openInterest.oi(id),
            'oiChange': openInterest.change(id),
            'iv': 18.0,
            'delta': greeks(
              right: right,
              spot: spot.ltp,
              strike: strike.toDouble(),
              years: years,
              iv: .18,
            ).delta,
          };
        }
      }
      if (cells.length > 1) rows.add(cells);
    }
    return {
      'chainId': key,
      'spot': spot.ltp,
      'atm': (spot.ltp / step).round() * step,
      'status': years > 0 ? 'open' : 'expired',
      'strikes': strikes,
      'asOf': clock.wallNow().millisecondsSinceEpoch,
      'rows': rows,
    };
  }
}

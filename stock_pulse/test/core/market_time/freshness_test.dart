import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10, 5);

  Freshness at(
    Duration age, {
    bool fromCache = false,
    bool socketLive = true,
    MarketPhase phase = MarketPhase.open,
    bool noAsOf = false,
  }) => freshnessOf(
    asOf: noAsOf ? null : now.subtract(age),
    fromCache: fromCache,
    serverNow: now,
    socketLive: socketLive,
    phase: phase,
  );

  test('age 4.9 / 5.0 / 5.1 s → live / live / stale (NFR-7)', () {
    expect(at(const Duration(milliseconds: 4900)), Freshness.live);
    expect(at(const Duration(seconds: 5)), Freshness.live);
    expect(at(const Duration(milliseconds: 5100)), Freshness.stale);
  });

  test('socket down or fromCache → stale, before phase', () {
    expect(at(Duration.zero, socketLive: false), Freshness.stale);
    expect(at(Duration.zero, fromCache: true), Freshness.stale);
    expect(
      at(Duration.zero, socketLive: false, phase: MarketPhase.closed),
      Freshness.stale,
    );
  });

  test('pre-open / closed → closed; asOf null → stale', () {
    expect(at(Duration.zero, phase: MarketPhase.preOpen), Freshness.closed);
    expect(at(Duration.zero, phase: MarketPhase.closed), Freshness.closed);
    expect(at(Duration.zero, noAsOf: true), Freshness.stale);
  });
}

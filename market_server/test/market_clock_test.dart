import 'dart:async';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

/// Tue 10 Nov 2026 10:00 IST.
final wall = DateTime.utc(2026, 11, 10, 4, 30);

final cal = MarketCalendar(
  holidays: {const IstDate(2026, 11, 12)}, // Thursday
  holidaySourceDate: 'test fixture',
);

void main() {
  group('demo mode (FR-116, AC1)', () {
    void expectDemoStart(DateTime wallNow, IstDate expectedDay) {
      final clock = MarketClock.demo(cal, wall: () => wallNow);
      expect(clock.mode, ClockMode.demo);
      expect(clock.overridden, isTrue);
      expect(clock.wallNow(), wallNow, reason: 'wall time unchanged');
      expect(clock.marketNow(), Ist.at(expectedDay, 10, 0));
      expect(cal.phaseAt(clock.marketNow()), MarketPhase.open);
    }

    test('weekday afternoon → 10:00 IST today', () {
      expectDemoStart(
        Ist.at(const IstDate(2026, 11, 10), 17, 45),
        const IstDate(2026, 11, 10),
      );
    });

    test('weekend → 10:00 IST on Monday', () {
      expectDemoStart(
        Ist.at(const IstDate(2026, 11, 7), 9, 0),
        const IstDate(2026, 11, 9),
      );
    });

    test('holiday → 10:00 IST on the next trading day', () {
      expectDemoStart(
        Ist.at(const IstDate(2026, 11, 12), 11, 0),
        const IstDate(2026, 11, 13),
      );
    });

    test('IST date is used, not the UTC date (21:00 UTC Mon = Tue IST)', () {
      expectDemoStart(
        DateTime.utc(2026, 11, 9, 21),
        const IstDate(2026, 11, 10),
      );
    });

    test('market time keeps running with the wall clock', () {
      var now = wall;
      final clock = MarketClock.demo(cal, wall: () => now);
      final start = clock.marketNow();
      now = now.add(const Duration(seconds: 90));
      expect(clock.marketNow(), start.add(const Duration(seconds: 90)));
    });
  });

  test('real mode follows wall time and is not overridden', () {
    final clock = MarketClock(mode: ClockMode.real, wall: () => wall);
    expect(clock.marketNow(), wall);
    expect(clock.overridden, isFalse);
  });

  test('jumpTo moves market time only and emits a jump', () {
    final clock = FakeMarketClock(wallStart: wall);
    final jumps = <ClockJump>[];
    clock.jumps.listen(jumps.add);
    final target = DateTime.utc(2026, 11, 10, 9, 50);

    clock.jumpTo(target);

    expect(clock.wallNow(), wall);
    expect(clock.marketNow(), target);
    expect(clock.overridden, isTrue);
    expect(jumps.single.fromMarket, wall);
    expect(jumps.single.toMarket, target);
  });

  test('advance moves wall and market together', () {
    final clock = FakeMarketClock(
      wallStart: wall,
      marketStart: wall.add(const Duration(hours: 1)),
    );
    clock.advance(const Duration(seconds: 10));
    expect(clock.wallNow(), wall.add(const Duration(seconds: 10)));
    expect(clock.marketNow(), wall.add(const Duration(hours: 1, seconds: 10)));
  });

  test('delay completes on advance, in due order', () async {
    final clock = FakeMarketClock(wallStart: wall);
    final done = <String>[];
    unawaited(
      clock.delay(const Duration(seconds: 2)).then((_) => done.add('b')),
    );
    unawaited(
      clock.delay(const Duration(seconds: 1)).then((_) => done.add('a')),
    );
    unawaited(
      clock.delay(const Duration(seconds: 5)).then((_) => done.add('c')),
    );

    clock.advance(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);

    expect(done, ['a', 'b']);
  });
}

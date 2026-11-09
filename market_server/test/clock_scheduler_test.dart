import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

/// No holidays, so expiries are plain Tuesdays (NIFTY weekly).
final cal = MarketCalendar(holidays: const {}, holidaySourceDate: 'test');

DateTime ist(IstDate d, int h, int m, [int s = 0]) => Ist.at(d, h, m, s);

const mon = IstDate(2026, 11, 9);
const tue = IstDate(2026, 11, 10); // NIFTY expiry
const wed = IstDate(2026, 11, 11);

({FakeMarketClock clock, ClockScheduler scheduler, List<String> log}) setup(
  DateTime marketStart,
) {
  final clock = FakeMarketClock(
    wallStart: DateTime.utc(2026, 11),
    marketStart: marketStart,
  );
  final scheduler = ClockScheduler(clock, cal);
  final log = <String>[];
  for (final kind in BoundaryKind.values) {
    scheduler.on(kind, (e) => log.add(e.key));
  }
  return (clock: clock, scheduler: scheduler, log: log);
}

void main() {
  test('15:19:59 → 15:20:00 fires squareOff once', () {
    final s = setup(ist(mon, 15, 19, 59));
    s.scheduler.tick();
    expect(s.log, isEmpty);

    s.clock.advance(const Duration(seconds: 1));
    s.scheduler.tick();
    s.scheduler.tick();
    s.clock.advance(const Duration(seconds: 5));
    s.scheduler.tick();

    expect(s.log, ['squareOff@2026-11-09']);
  });

  test('jump over 2 days replays the boundaries once each, in order (AC3)', () {
    final s = setup(ist(mon, 10, 0));
    s.clock.jumpTo(ist(wed, 10, 0));
    s.scheduler.tick();
    s.scheduler.tick();

    expect(s.log, [
      'squareOff@2026-11-09',
      'close@2026-11-09',
      'dayRoll@2026-11-10',
      'open@2026-11-10',
      'squareOff@2026-11-10',
      'settle@2026-11-10',
      'close@2026-11-10',
      'dayRoll@2026-11-11',
      'open@2026-11-11',
    ]);
    expect(s.scheduler.lastProcessed, ist(wed, 10, 0));
  });

  test('settle fires only on an expiry day, before close', () {
    final s = setup(ist(mon, 15, 0));
    s.clock.jumpTo(ist(mon, 15, 31));
    s.scheduler.tick();
    expect(s.log, ['squareOff@2026-11-09', 'close@2026-11-09']);
  });

  test('a processed key is not replayed after resetTo an earlier time', () {
    final s = setup(ist(tue, 15, 0));
    s.clock.jumpTo(ist(tue, 15, 25));
    s.scheduler.tick();
    expect(s.log, ['squareOff@2026-11-10']);

    // Backward jumps are refused upstream; tick ignores them.
    s.clock.jumpTo(ist(tue, 15, 0));
    s.scheduler.tick();
    s.clock.jumpTo(ist(tue, 15, 26));
    s.scheduler.tick();
    expect(s.log, ['squareOff@2026-11-10']);

    // /debug/reset clears processed keys.
    s.scheduler.resetTo(ist(tue, 15, 0));
    s.clock.jumpTo(ist(tue, 15, 21));
    s.scheduler.tick();
    expect(s.log, ['squareOff@2026-11-10', 'squareOff@2026-11-10']);
  });

  test(
    'more than 10 trading days → one fast-forward dayRoll, then 10 days',
    () {
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11),
        marketStart: ist(mon, 10, 0),
      );
      final scheduler = ClockScheduler(clock, cal);
      final rolls = <BoundaryEvent>[];
      scheduler.on(BoundaryKind.dayRoll, rolls.add);

      clock.jumpTo(ist(const IstDate(2026, 12, 9), 10, 0)); // Wed, 4 weeks on
      scheduler.tick();

      expect(rolls.first.fastForward, isTrue);
      expect(rolls.where((e) => e.fastForward), hasLength(1));
      // The fast-forward roll is on the 10th-last trading day, and every later
      // trading day up to today gets its own roll.
      expect(rolls.first.tradingDay, const IstDate(2026, 11, 26));
      expect(rolls, hasLength(10));
      expect(rolls.last.tradingDay, const IstDate(2026, 12, 9));
    },
  );

  test('a throwing handler does not stop the others; key stays processed', () {
    final s = setup(ist(mon, 15, 19));
    final ran = <String>[];
    final scheduler = s.scheduler
      ..on(BoundaryKind.squareOff, (_) => throw StateError('boom'))
      ..on(BoundaryKind.squareOff, (e) => ran.add(e.key));
    s.clock.advance(const Duration(minutes: 2));
    scheduler.tick();
    scheduler.tick();
    expect(ran, ['squareOff@2026-11-09']);
  });

  test('phaseChanges emits when the phase changes', () async {
    final s = setup(ist(mon, 8, 59));
    final phases = <MarketPhase>[];
    s.scheduler.phaseChanges.listen(phases.add);
    s.clock.advance(const Duration(minutes: 1));
    s.scheduler.tick();
    s.clock.advance(const Duration(minutes: 15));
    s.scheduler.tick();
    s.scheduler.tick();
    expect(phases, [MarketPhase.preOpen, MarketPhase.open]);
  });
}

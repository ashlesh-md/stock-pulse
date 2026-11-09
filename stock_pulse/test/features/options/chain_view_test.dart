import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

void main() {
  const ce = OptionCell(
    contractId: 'CE1',
    ltp: 10,
    change: 1,
    oi: 100,
    oiChange: 5,
    iv: 13.4,
    delta: 0.5,
  );
  final asOf = DateTime.utc(2026, 11, 10, 4);

  group('OptionCell', () {
    test('copyWith changes only the given fields', () {
      final moved = ce.copyWith(ltp: 11, oi: 101);
      expect(
        (moved.ltp, moved.oi, moved.change, moved.iv),
        (11.0, 101, 1.0, 13.4),
      );
      expect(ce.copyWith(), ce);
      expect(ce.copyWith().hashCode, ce.hashCode);
      expect(moved, isNot(ce));
      expect(
        ce.copyWith(change: 2, oiChange: 6, iv: 14, delta: 0.6),
        isA<OptionCell>()
            .having((c) => c.change, 'change', 2)
            .having((c) => c.oiChange, 'oiChange', 6)
            .having((c) => c.delta, 'delta', 0.6),
      );
    });
  });

  group('ChainRow', () {
    test('copyWith keeps the other side; equal by strike and cells', () {
      const row = ChainRow(strike: 24000, ce: ce);
      final withPe = row.copyWith(pe: ce.copyWith(ltp: 9));
      expect(withPe.ce, ce);
      expect(withPe.pe?.ltp, 9);
      expect(row.copyWith(), row);
      expect(row.copyWith().hashCode, row.hashCode);
      expect(withPe, isNot(row));
    });
  });

  group('ChainView', () {
    const row = ChainRow(strike: 24000, ce: ce);
    final view = ChainView(
      chainId: 'NIFTY:2026-11-10',
      seq: 1,
      asOf: asOf,
      spot: 24010,
      atm: 24000,
      status: ChainStatus.open,
      strikes: const [24000],
      rows: const {24000: row},
      exAsOf: {'CE1': DateTime.utc(2026, 11, 10, 3)},
    );

    test('asOfFor prefers a cell-level asOf', () {
      expect(view.asOfFor('CE1'), DateTime.utc(2026, 11, 10, 3));
      expect(view.asOfFor('PE1'), asOf);
    });

    test('rows compare by identity, so an untouched row keeps equality', () {
      expect(view.copyWith(), view);
      expect(view.copyWith().hashCode, view.hashCode);
      expect(view.copyWith(rows: {24000: row}), view);
      expect(view.copyWith(rows: {24000: row.copyWith()}), isNot(view));
      expect(view.copyWith(rows: const {}), isNot(view));
    });

    test('copyWith replaces every field it is given', () {
      final next = view.copyWith(
        seq: 2,
        asOf: asOf.add(const Duration(seconds: 1)),
        spot: 24020,
        atm: 24050,
        status: ChainStatus.expired,
        strikes: const [24050],
        exAsOf: const {},
      );
      expect(next.seq, 2);
      expect(next.status, ChainStatus.expired);
      expect(next.strikes, [24050]);
      expect(next.exAsOf, isEmpty);
      expect(next, isNot(view));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/features/options/application/chain_state.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

void main() {
  test('chain states compare by value and copy with no changes', () {
    final view = ChainView(
      chainId: 'NIFTY:2026-11-09',
      seq: 1,
      asOf: DateTime.utc(2026),
      spot: 24500,
      atm: 24500,
      status: ChainStatus.open,
      strikes: const [],
      rows: const {},
    );
    final a = ChainState(expiries: const [], expiry: 'x', view: view);
    final b = ChainState(expiries: const [], expiry: 'x', view: view);
    expect(a.copyWith(), a);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}

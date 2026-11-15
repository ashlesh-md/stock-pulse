import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

/// A NIFTY chain with 41 strikes around [fixtureAtm]; the ATM call carries
/// greeks and the strike above ATM has no put.
class MockChainRepository extends Mock implements ChainRepository {}

const fixtureAtm = 24500;
final fixtureStrikes = [for (var i = -20; i <= 20; i++) fixtureAtm + i * 50];
OptionCell fixtureCell(String id, int oi, {bool greeks = false}) => OptionCell(
  contractId: id,
  ltp: 141.25,
  change: 1,
  oi: oi,
  oiChange: id.endsWith('PE') ? -300 : 1200,
  iv: greeks ? 13.4 : null,
  delta: greeks ? .52 : null,
);
ChainView fixtureChain() => ChainView(
  chainId: 'NIFTY:2026-11-09',
  seq: 1,
  asOf: DateTime.utc(2026, 11, 8),
  spot: 24512.35,
  atm: fixtureAtm,
  status: ChainStatus.open,
  strikes: fixtureStrikes,
  rows: {
    for (final k in fixtureStrikes)
      k: ChainRow(
        strike: k,
        ce: fixtureCell(
          'NIFTY${k}CE',
          k == fixtureAtm ? 1520000 : 600000,
          greeks: k == fixtureAtm,
        ),
        pe: k == fixtureAtm + 50 ? null : fixtureCell('NIFTY${k}PE', 800000),
      ),
  },
);

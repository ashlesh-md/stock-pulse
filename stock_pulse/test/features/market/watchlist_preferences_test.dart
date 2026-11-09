import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/market/application/watchlist_state.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

const a = Instrument(
  symbol: 'A',
  name: 'A',
  exchange: 'NSE',
  sector: '',
  tickSize: .05,
  lotSize: 1,
);
const b = Instrument(
  symbol: 'B',
  name: 'B',
  exchange: 'NSE',
  sector: '',
  tickSize: .05,
  lotSize: 1,
);
const c = Instrument(
  symbol: 'C',
  name: 'C',
  exchange: 'NSE',
  sector: '',
  tickSize: .05,
  lotSize: 1,
);

void main() {
  test('favourites precede the saved order and unknown ids are ignored', () {
    const state = WatchlistState(
      instruments: [a, b, c],
      quotes: {},
      favouriteIds: {'C'},
      watchlistOrder: ['B', 'C', 'missing', 'A'],
    );
    expect(state.orderedInstruments.map((i) => i.id), ['C', 'B', 'A']);
    expect(state.copyWith(quotes: const {}).favouriteIds, {'C'});
  });
  test(
    'preferences copy keeps favourites and order without changing defaults',
    () {
      final prefs = LocalPrefsData.defaults.copyWith(
        favouriteIds: {'C'},
        watchlistOrder: ['B', 'A'],
      );
      expect(prefs.copyWith(hapticsEnabled: false).favouriteIds, {'C'});
      expect(prefs.watchlistOrder, ['B', 'A']);
      expect(
        prefs,
        LocalPrefsData.defaults.copyWith(
          favouriteIds: {'C'},
          watchlistOrder: ['B', 'A'],
        ),
      );
      expect(
        prefs.hashCode,
        LocalPrefsData.defaults
            .copyWith(favouriteIds: {'C'}, watchlistOrder: ['B', 'A'])
            .hashCode,
      );
      expect(LocalPrefsData.defaults.favouriteIds, isEmpty);
    },
  );
}

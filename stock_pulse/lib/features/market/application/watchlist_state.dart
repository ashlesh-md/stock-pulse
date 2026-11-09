import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

@immutable
class WatchlistState {
  const WatchlistState({
    required this.instruments,
    required this.quotes,
    this.favouriteIds = const {},
    this.watchlistOrder = const [],
  });

  final Set<String> favouriteIds;
  final List<String> watchlistOrder;

  List<Instrument> get orderedInstruments {
    final ranks = {
      for (var i = 0; i < watchlistOrder.length; i++) watchlistOrder[i]: i,
    };
    final original = {
      for (var i = 0; i < instruments.length; i++) instruments[i].id: i,
    };
    return List.of(instruments)..sort((a, b) {
      final pinned =
          (favouriteIds.contains(b.id) ? 1 : 0) -
          (favouriteIds.contains(a.id) ? 1 : 0);
      if (pinned != 0) return pinned;
      return (ranks[a.id] ?? watchlistOrder.length + original[a.id]!).compareTo(
        ranks[b.id] ?? watchlistOrder.length + original[b.id]!,
      );
    });
  }

  final List<Instrument> instruments;

  /// symbol → latest quote. A new map on every update (immutable state).
  final Map<String, Quote> quotes;

  /// Number of stocks up today, for the header.
  int get advancing => quotes.values.where((q) => q.change > 0).length;
  int get declining => quotes.values.where((q) => q.change < 0).length;

  @override
  bool operator ==(Object other) =>
      other is WatchlistState &&
      listEquals(instruments, other.instruments) &&
      mapEquals(quotes, other.quotes) &&
      setEquals(favouriteIds, other.favouriteIds) &&
      listEquals(watchlistOrder, other.watchlistOrder);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(instruments),
    Object.hashAllUnordered(
      quotes.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(favouriteIds),
    Object.hashAll(watchlistOrder),
  );

  WatchlistState copyWith({
    Map<String, Quote>? quotes,
    Set<String>? favouriteIds,
    List<String>? watchlistOrder,
  }) => WatchlistState(
    instruments: instruments,
    quotes: quotes ?? this.quotes,
    favouriteIds: favouriteIds ?? this.favouriteIds,
    watchlistOrder: watchlistOrder ?? this.watchlistOrder,
  );
}

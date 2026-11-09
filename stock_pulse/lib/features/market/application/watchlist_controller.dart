import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/market/application/watchlist_state.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// The one controller for the watchlist screen.
///
/// 1. REST: instrument list + quote snapshot → the screen shows prices at
///    once, even before the WebSocket has connected.
/// 2. WebSocket: subscribe in `quote` mode and merge each batch into state.
/// 3. `ref.onDispose` cancels the stream → the repository unsubscribes.
class WatchlistController extends AsyncNotifier<WatchlistState> {
  @override
  Future<WatchlistState> build() async {
    final repo = ref.watch(marketRepositoryProvider);
    List<String>? symbols;
    StreamSubscription<List<Quote>>? live;
    var visible = ref.read(screenVisibleProvider(ScreenId.watchlist));

    void syncSubscription({required bool shouldListen}) {
      final ids = symbols;
      if (!shouldListen || ids == null) {
        unawaited(live?.cancel());
        live = null;
        return;
      }
      if (live != null) return;
      live = repo.watchQuotes(ids, FeedMode.quote).listen((batch) {
        final current = state.value;
        if (current == null) return;
        state = AsyncData(
          current.copyWith(
            quotes: {...current.quotes, for (final q in batch) q.symbol: q},
          ),
        );
      });
    }

    ref.listen(screenVisibleProvider(ScreenId.watchlist), (_, next) {
      visible = next;
      syncSubscription(shouldListen: next);
    });
    ref.onDispose(() => unawaited(live?.cancel()));
    ref.listen(localPrefsProvider, (_, next) {
      final current = state.value;
      final prefs = next.value?.data;
      if (current != null && prefs != null) {
        state = AsyncData(
          current.copyWith(
            favouriteIds: prefs.favouriteIds,
            watchlistOrder: prefs.watchlistOrder,
          ),
        );
      }
    });
    final instruments = (await repo.getInstruments()).getOrThrow();
    if (!ref.mounted) {
      return WatchlistState(instruments: instruments, quotes: const {});
    }
    final requestedSymbols = [for (final i in instruments) i.symbol];
    symbols = requestedSymbols;
    final result = await repo.getQuotes(requestedSymbols);
    final cached = result is Failure
        ? repo.latestQuotes(requestedSymbols)
        : const <Quote>[];
    final snapshot = result is Failure && cached.isNotEmpty
        ? cached
        : result.getOrThrow();

    if (!ref.mounted) {
      return WatchlistState(
        instruments: instruments,
        quotes: {for (final q in snapshot) q.symbol: q},
      );
    }
    final preferences =
        ref.read(localPrefsProvider).value?.data ?? LocalPrefsData.defaults;
    syncSubscription(shouldListen: visible);

    return WatchlistState(
      instruments: instruments,
      favouriteIds: preferences.favouriteIds,
      watchlistOrder: preferences.watchlistOrder,
      quotes: {for (final q in snapshot) q.symbol: q},
    );
  }

  Future<void> toggleFavourite(String id) async {
    final current = state.value;
    if (current == null) return;
    final favourites = Set<String>.of(current.favouriteIds);
    if (!favourites.remove(id)) favourites.add(id);
    state = AsyncData(
      current.copyWith(favouriteIds: Set.unmodifiable(favourites)),
    );
    await _savePreferences();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;
    final ordered = current.orderedInstruments;
    if (oldIndex < 0 ||
        oldIndex >= ordered.length ||
        newIndex < 0 ||
        newIndex >= ordered.length) {
      return;
    }
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    state = AsyncData(
      current.copyWith(
        watchlistOrder: List.unmodifiable(ordered.map((i) => i.id)),
      ),
    );
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    final current = state.requireValue;
    final prefs = await ref.read(localPrefsProvider.future);
    if (!ref.mounted) return;
    await prefs.update(
      (data) => data.copyWith(
        favouriteIds: current.favouriteIds,
        watchlistOrder: current.watchlistOrder,
      ),
    );
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

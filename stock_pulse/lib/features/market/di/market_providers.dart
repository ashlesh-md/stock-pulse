import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/market/application/stock_detail_controller.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/application/watchlist_controller.dart';
import 'package:stock_pulse/features/market/application/watchlist_state.dart';

final watchlistControllerProvider =
    AsyncNotifierProvider.autoDispose<WatchlistController, WatchlistState>(
      WatchlistController.new,
    );

/// One controller per instrument id; closing the page disposes it, which
/// unsubscribes its quotes.
final stockDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<StockDetailController, StockDetailState, String>(
      StockDetailController.new,
    );

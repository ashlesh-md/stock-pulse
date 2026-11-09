import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

typedef TicketContract = ({Instrument instrument, double ltp});

/// Throws the `AppError` when the contract cannot be loaded.
Future<TicketContract> loadTicketContract(Ref ref, String id) async {
  final market = ref.watch(marketRepositoryProvider);
  final instrument = (await market.getInstrument(id)).getOrThrow();
  final cached = market.latest(id);
  if (cached != null) return (instrument: instrument, ltp: cached.ltp);
  final quotes = (await market.getQuotes([id])).getOrThrow();
  return (instrument: instrument, ltp: quotes.firstOrNull?.ltp ?? 0);
}

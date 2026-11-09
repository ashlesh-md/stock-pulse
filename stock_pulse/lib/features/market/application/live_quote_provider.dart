import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// Latest quote already received by the market repository, without starting
/// another stream subscription. Presentation code consumes this facade rather
/// than depending on the repository's DI wiring.
final latestQuoteSnapshotProvider = Provider.autoDispose.family<Quote?, String>(
  (ref, instrumentId) =>
      ref.watch(marketRepositoryProvider).latest(instrumentId),
);

/// Static contract metadata already loaded by the market repository.
final instrumentSnapshotProvider = Provider.autoDispose
    .family<Instrument?, String>(
      (ref, instrumentId) =>
          ref.watch(marketRepositoryProvider).instrument(instrumentId),
    );

/// One live quote; replays the cached value first. autoDispose: the
/// subscription (and the socket holder) ends when no widget watches it.
final liveQuoteProvider = StreamProvider.autoDispose
    .family<Quote, ({String id, int throttleMs})>(
      (ref, key) => ref
          .watch(marketRepositoryProvider)
          .watchQuotes([key.id], FeedMode.quote, throttleMs: key.throttleMs)
          .expand((batch) => batch),
    );

import 'package:flutter/foundation.dart';
import 'package:stock_pulse/app/snapshot/instrument_snapshot.dart';
import 'package:stock_pulse/core/storage/domain/snapshot.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// Any field change bumps this; a file with another version is discarded.
const kSnapshotSchema = 1;

/// A snapshot older than this (device clock) is discarded.
const kSnapshotMaxAge = Duration(days: 7);

/// Over this the file is still written, with one `cache_oversize` log.
const kSnapshotBudgetBytes = 64 * 1024;

/// What a cold start paints before the first live frame.
/// Facts only: the portfolio summary is derived on seed, never stored.
@immutable
class AppSnapshot implements Snapshot {
  const AppSnapshot({
    required this.savedAt,
    required this.watchlistIds,
    required this.quotes,
    required this.positions,
    required this.holdings,
    this.instruments = const [],
  });

  @override
  final DateTime savedAt;
  final List<String> watchlistIds;

  /// `fromCache: true` after decode, so they read stale until a live frame.
  final List<Quote> quotes;
  final List<Instrument> instruments;
  final List<Position> positions;
  final List<Holding> holdings;

  /// Schema v1. Every quote comes back `fromCache: true`
  /// with seq 0, so it reads stale until the first live frame replaces it.
  /// Throws [FormatException] on any bad field.
  factory AppSnapshot.fromJson(Map<String, Object?> j) {
    if (j['schemaVersion'] != kSnapshotSchema) {
      throw FormatException('schemaVersion ${j['schemaVersion']}');
    }
    try {
      final watchlist = j['watchlist']! as Map<String, Object?>;
      List<Map<String, Object?>> maps(Object? list) =>
          (list! as List).cast<Map<String, Object?>>();
      return AppSnapshot(
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          j['savedAt']! as int,
          isUtc: true,
        ),
        watchlistIds: List.unmodifiable(
          (watchlist['ids']! as List).cast<String>(),
        ),
        quotes: List.unmodifiable([
          for (final q in maps(watchlist['quotes']))
            Quote.fromJson(q).copyWith(fromCache: true, seq: 0),
        ]),
        positions: List.unmodifiable(
          maps(j['positions']).map(Position.fromJson),
        ),
        instruments: List.unmodifiable([
          for (final entry in maps(j['instruments'] ?? const []))
            Instrument.fromJson(entry),
        ]),
        holdings: List.unmodifiable(maps(j['holdings']).map(Holding.fromJson)),
      );
    } on TypeError catch (e) {
      // A missing or mistyped field fails a cast or a null check.
      throw FormatException('bad snapshot field: $e');
    }
  }

  /// Facts only: no summary, funds, orders or chain prices.
  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': kSnapshotSchema,
    'savedAt': savedAt.millisecondsSinceEpoch,
    'watchlist': {
      'ids': watchlistIds,
      'quotes': [for (final q in quotes) q.toJson()],
    },
    'positions': [for (final p in positions) p.toJson()],
    if (instruments.isNotEmpty)
      'instruments': instruments.map(instrumentSnapshot).toList(),
    'holdings': [for (final h in holdings) h.toJson()],
  };

  AppSnapshot copyWith({
    DateTime? savedAt,
    List<String>? watchlistIds,
    List<Quote>? quotes,
    List<Position>? positions,
    List<Holding>? holdings,
    List<Instrument>? instruments,
  }) => AppSnapshot(
    savedAt: savedAt ?? this.savedAt,
    watchlistIds: watchlistIds ?? this.watchlistIds,
    quotes: quotes ?? this.quotes,
    positions: positions ?? this.positions,
    holdings: holdings ?? this.holdings,
    instruments: instruments ?? this.instruments,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSnapshot &&
      other.savedAt == savedAt &&
      listEquals(other.watchlistIds, watchlistIds) &&
      listEquals(other.quotes, quotes) &&
      listEquals(other.positions, positions) &&
      listEquals(other.holdings, holdings) &&
      listEquals(other.instruments, instruments);

  @override
  int get hashCode => Object.hash(
    savedAt,
    Object.hashAll(watchlistIds),
    Object.hashAll(quotes),
    Object.hashAll(positions),
    Object.hashAll(holdings),
    Object.hashAll(instruments),
  );
}

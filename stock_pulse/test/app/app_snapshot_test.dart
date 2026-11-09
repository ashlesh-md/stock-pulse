import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart' show OptionRight;
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/app/snapshot/instrument_snapshot.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

import '../core/storage/storage_fixtures.dart';

void main() {
  test('toJson / fromJson round-trips; decoded quotes are fromCache', () {
    final snap = snapshotWith();
    final json = jsonDecode(jsonEncode(snap.toJson())) as Map<String, Object?>;
    final back = AppSnapshot.fromJson(json);

    expect(back, snap);
    expect(json['schemaVersion'], kSnapshotSchema);
    expect(back.quotes.every((q) => q.fromCache && q.seq == 0), isTrue);
  });

  test('a live quote is stored and comes back fromCache', () {
    final live = cachedQuote(
      'RELIANCE',
      1432.5,
    ).copyWith(fromCache: false, seq: 41);
    final snap = snapshotWith().copyWith(
      watchlistIds: ['RELIANCE'],
      quotes: [live],
    );
    final back = AppSnapshot.fromJson(snap.toJson());

    expect(back.quotes.single.fromCache, isTrue);
    expect(back.quotes.single.seq, 0);
    expect(back.quotes.single.ltp, 1432.5);
  });

  test('instrument facts round-trip with optional option fields', () {
    const instrument = Instrument(
      symbol: 'NIFTY26NOV25000CE',
      name: 'NIFTY 25000 CE',
      exchange: 'NFO',
      sector: 'Index options',
      tickSize: 0.05,
      lotSize: 75,
      kind: InstrumentKind.option,
      bandLow: 10,
      bandHigh: 500,
      strikeStep: 50,
      underlying: 'NIFTY',
      expiry: '2026-11-26',
      strike: 25000,
      right: OptionRight.ce,
    );
    final snapshot = snapshotWith().copyWith(instruments: [instrument]);
    final restored = AppSnapshot.fromJson(snapshot.toJson());

    expect(instrumentSnapshot(instrument), containsPair('right', 'ce'));
    expect(restored.instruments, [instrument]);
    expect(restored.toJson()['instruments'], hasLength(1));
  });

  // Facts only: the summary is recomputed from them.
  test('the snapshot has no summary field', () {
    final json = snapshotWith().toJson();
    expect(json.containsKey('summary'), isFalse);
    expect(json.keys, {
      'schemaVersion',
      'savedAt',
      'watchlist',
      'positions',
      'holdings',
    });
  });

  test('a bad field throws FormatException', () {
    final json = snapshotWith().toJson()..['positions'] = 'nope';
    expect(() => AppSnapshot.fromJson(json), throwsFormatException);
    expect(
      () => AppSnapshot.fromJson({'schemaVersion': 1}),
      throwsFormatException,
    );
  });
}

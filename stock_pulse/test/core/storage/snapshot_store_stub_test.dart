import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

import '../../helpers/fake_snapshot_store.dart';

void main() {
  final snap = AppSnapshot(
    savedAt: DateTime.utc(2026, 11, 6),
    watchlistIds: const ['NIFTY', 'RELIANCE'],
    quotes: const [],
    positions: const [],
    holdings: const [],
  );

  test('AppSnapshot compares by value', () {
    expect(snap, snap.copyWith(watchlistIds: ['NIFTY', 'RELIANCE']));
    expect(snap == snap.copyWith(watchlistIds: ['NIFTY']), isFalse);
  });

  test('FakeSnapshotStore via provider: dirty flag, saves, clear', () async {
    final fake = FakeSnapshotStore();
    final container = ProviderContainer(
      overrides: [
        snapshotStoreProvider.overrideWithValue(fake),
        snapshotProvider.overrideWith((ref) async => snap),
      ],
    );
    addTearDown(container.dispose);

    final store = container.read(snapshotStoreProvider);
    store.markStructuralDirty();
    expect(fake.dirty, isTrue);
    await store.saveNow(snap);
    expect(fake.saved, [snap]);
    expect(fake.dirty, isFalse);
    await store.clear();
    expect(fake.clears, 1);
    expect(await container.read(snapshotProvider.future), snap);
  });
}

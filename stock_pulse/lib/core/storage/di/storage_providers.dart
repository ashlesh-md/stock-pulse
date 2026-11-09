import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';

/// Overridden in `bootstrap()` with the `FileSnapshotStore`; tests override
/// it with `FakeSnapshotStore` (test/helpers/fake_snapshot_store.dart).
final snapshotStoreProvider = Provider<SnapshotStore>(
  (ref) => throw UnimplementedError(
    'snapshotStoreProvider is overridden in bootstrap(); '
    'override it with FakeSnapshotStore in tests',
  ),
);

/// Overridden in `bootstrap()` and read lazily; tests override it
/// with `FakeLocalPrefs`.
final localPrefsProvider = FutureProvider<LocalPrefs>(
  (ref) => throw UnimplementedError(
    'localPrefsProvider is overridden in bootstrap(); '
    'override it with FakeLocalPrefs in tests',
  ),
);

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/application/snapshot_scheduler.dart';

import '../../helpers/fake_snapshot_store.dart';
import 'storage_fixtures.dart';

void main() {
  late FakeSnapshotStore store;
  late StreamController<void> resync;
  late bool liveData;
  late bool live;
  late SnapshotScheduler scheduler;

  setUp(() {
    store = FakeSnapshotStore();
    resync = StreamController<void>.broadcast(sync: true);
    addTearDown(resync.close);
    liveData = true;
    live = true;
    scheduler = SnapshotScheduler(
      store: store,
      isDirty: () => store.dirty,
      capture: snapshotWith,
      hasLiveData: () => liveData,
      isLive: () => live,
      resyncCompleted: resync.stream,
    );
  });
  tearDown(() => scheduler.dispose());

  // testWidgets for its fake timers.
  testWidgets('dirty + 30 s: one save; not dirty: none', (tester) async {
    scheduler.onShow();
    store.markStructuralDirty();
    await tester.pump(const Duration(seconds: 30));
    expect(store.saved, hasLength(1));

    await tester.pump(const Duration(seconds: 30)); // clean now
    expect(store.saved, hasLength(1));
    scheduler.onHide();
  });

  testWidgets('the timer stops on hide', (tester) async {
    scheduler.onShow();
    scheduler.onHide();
    expect(store.saved, hasLength(1)); // the hide save itself
    store.markStructuralDirty();
    await tester.pump(const Duration(seconds: 60));
    expect(store.saved, hasLength(1));
  });

  testWidgets('offline start with no live data + hide: no save', (
    tester,
  ) async {
    liveData = false;
    live = false;
    scheduler.onShow();
    store.markStructuralDirty();
    await tester.pump(const Duration(seconds: 30));
    scheduler.onHide();
    expect(store.saved, isEmpty);
  });

  testWidgets('live data seen once stays seen', (tester) async {
    scheduler.onShow();
    await tester.pump(const Duration(seconds: 30)); // latches hasLiveData
    liveData = false;
    scheduler.onHide();
    expect(store.saved, hasLength(1));
  });

  testWidgets('resync saves only while live', (tester) async {
    scheduler.onShow();
    live = false; // reconnecting
    resync.add(null);
    await tester.pump();
    expect(store.saved, isEmpty);

    live = true;
    resync.add(null);
    await tester.pump();
    expect(store.saved, hasLength(1));
    scheduler.onHide();
  });
}

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_local_prefs.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

import '../../helpers/fake_crash_reporter.dart';

void main() {
  late Directory dir;
  late FakeCrashReporter reporter;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('prefs_');
    reporter = FakeCrashReporter();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File prefsFile() => File('${dir.path}/${FileLocalPrefs.fileName}');
  Future<LocalPrefs> load() => FileLocalPrefs(
    AtomicJsonFile(Future.value(dir), FileLocalPrefs.fileName),
    reporter,
  ).load();

  test('missing file: defaults, no log', () async {
    final prefs = await load();
    expect(prefs.data, LocalPrefsData.defaults);
    expect(reporter.logs, isEmpty);
  });

  for (final (name, content) in [
    ('corrupt', '{"schemaVersion": 1, "riskNo'),
    ('wrong schema', '{"schemaVersion": 2, "riskNoticeAcked": true}'),
    ('not an object', '[1]'),
    (
      'bad locale tag',
      '{"schemaVersion": 1, "riskNoticeAcked": true, "hapticsEnabled": true, '
          '"seenAlertIds": [], "localeOverride": "en-IN-x"}',
    ),
  ]) {
    test('$name: defaults and one prefs_discarded', () async {
      prefsFile().writeAsStringSync(content);
      final prefs = await load();

      expect(prefs.data, LocalPrefsData.defaults);
      expect(reporter.logsNamed('prefs_discarded'), hasLength(1));
    });
  }

  test('update is visible synchronously, then persisted', () async {
    final prefs = await load();
    final write = prefs.update(
      (p) =>
          p.copyWith(hapticsEnabled: false, lastChainUnderlying: 'BANKNIFTY'),
    );
    expect(prefs.data.hapticsEnabled, isFalse);
    await write;

    final again = await load();
    expect(again.data.hapticsEnabled, isFalse);
    expect(again.data.lastChainUnderlying, 'BANKNIFTY');
  });

  test('favourites and custom watchlist order survive restart', () async {
    final prefs = await load();
    await prefs.update(
      (p) => p.copyWith(favouriteIds: {'TCS'}, watchlistOrder: ['INFY', 'TCS']),
    );
    final again = await load();
    expect(again.data.favouriteIds, {'TCS'});
    expect(again.data.watchlistOrder, ['INFY', 'TCS']);
  });

  test('FR-189: consent and locale override survive a restart', () async {
    final prefs = await load();
    await prefs.update(
      (p) => p.copyWith(
        analyticsConsent: false,
        localeOverride: const Locale('en', 'IN'),
      ),
    );

    final again = await load();
    expect(again.data.analyticsConsent, isFalse);
    expect(again.data.localeOverride, const Locale('en', 'IN'));
  });

  test('notification explanation choice survives a restart', () async {
    final prefs = await load();
    await prefs.update((p) => p.copyWith(notificationExplainerShown: true));
    expect((await load()).data.notificationExplainerShown, isTrue);
  });

  test('unresolved order records survive restart', () async {
    final prefs = await load();
    await prefs.update(
      (p) => p.copyWith(pendingOrderRecords: ['{"clientKey":"k1"}']),
    );

    expect((await load()).data.pendingOrderRecords, ['{"clientKey":"k1"}']);
  });

  test('a v1 file from before consent and locale keeps the risk ack', () async {
    prefsFile().writeAsStringSync(
      '{"schemaVersion": 1, "riskNoticeAcked": true, "hapticsEnabled": false, '
      '"seenAlertIds": ["A1"], "lastChainUnderlying": null}',
    );

    final prefs = await load();

    expect(prefs.data.riskNoticeAcked, isTrue);
    expect(prefs.data.analyticsConsent, isTrue);
    expect(prefs.data.localeOverride, isNull);
    expect(reporter.logs, isEmpty);
  });

  test('a language-only locale tag loads', () async {
    prefsFile().writeAsStringSync(
      '{"schemaVersion": 1, "riskNoticeAcked": false, "hapticsEnabled": true, '
      '"seenAlertIds": [], "localeOverride": "hi"}',
    );

    expect((await load()).data.localeOverride, const Locale('hi'));
  });

  test('501 seen alert ids keep the newest 500', () async {
    final prefs = await load();
    for (var i = 0; i < 501; i++) {
      await prefs.update(
        (p) => p.copyWith(seenAlertIds: {...p.seenAlertIds, 'A$i'}),
      );
    }
    expect(prefs.data.seenAlertIds, hasLength(500));
    expect(prefs.data.seenAlertIds.contains('A0'), isFalse);
    expect(prefs.data.seenAlertIds.first, 'A1');

    final again = await load();
    expect(again.data.seenAlertIds, hasLength(500));
    expect(again.data.seenAlertIds.last, 'A500');
  });

  test('no directory (web): defaults in memory, updates kept', () async {
    final prefs = await FileLocalPrefs(
      AtomicJsonFile(null, FileLocalPrefs.fileName),
      reporter,
    ).load();
    await prefs.update((p) => p.copyWith(riskNoticeAcked: true));
    expect(prefs.data.riskNoticeAcked, isTrue);
  });
}

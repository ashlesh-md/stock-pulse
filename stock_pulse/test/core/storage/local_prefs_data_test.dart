import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

import '../../helpers/fake_local_prefs.dart';

void main() {
  test('defaults are false, true, empty, null', () {
    const d = LocalPrefsData.defaults;
    expect(d.riskNoticeAcked, isFalse);
    expect(d.hapticsEnabled, isTrue);
    expect(d.seenAlertIds, isEmpty);
    expect(d.lastChainUnderlying, isNull);
    expect(d.analyticsConsent, isTrue);
    expect(d.localeOverride, isNull);
  });

  test('FR-189: analytics consent and locale override copy and clear', () {
    final a = LocalPrefsData.defaults.copyWith(
      analyticsConsent: false,
      localeOverride: const Locale('hi'),
    );
    expect(a.analyticsConsent, isFalse);
    expect(a.localeOverride, const Locale('hi'));
    expect(
      a.copyWith(hapticsEnabled: false).localeOverride,
      const Locale('hi'),
    );
    expect(a.copyWith(clearLocaleOverride: true).localeOverride, isNull);
    expect(
      a.toString(),
      'LocalPrefsData(riskNoticeAcked: false, hapticsEnabled: true, '
      'analyticsConsent: false, seenAlertIds: 0, lastChainUnderlying: null, '
      'localeOverride: hi)',
    );
  });

  test('== and hashCode compare by value, set order ignored', () {
    const a = LocalPrefsData(
      riskNoticeAcked: true,
      hapticsEnabled: false,
      analyticsConsent: false,
      seenAlertIds: {'A1', 'A2'},
      lastChainUnderlying: 'NIFTY',
      localeOverride: Locale('en', 'IN'),
    );
    const b = LocalPrefsData(
      riskNoticeAcked: true,
      hapticsEnabled: false,
      analyticsConsent: false,
      seenAlertIds: {'A2', 'A1'},
      lastChainUnderlying: 'NIFTY',
      localeOverride: Locale('en', 'IN'),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == LocalPrefsData.defaults, isFalse);
  });

  test(
    'copyWith changes only the given fields and can clear the underlying',
    () {
      const a = LocalPrefsData(
        riskNoticeAcked: false,
        hapticsEnabled: true,
        analyticsConsent: true,
        seenAlertIds: {},
        lastChainUnderlying: 'NIFTY',
        localeOverride: null,
      );
      final b = a.copyWith(riskNoticeAcked: true);
      expect(b.riskNoticeAcked, isTrue);
      expect(b.lastChainUnderlying, 'NIFTY');
      expect(
        a.copyWith(clearLastChainUnderlying: true).lastChainUnderlying,
        isNull,
      );
    },
  );

  test(
    'FakeLocalPrefs: update is visible synchronously, clear resets',
    () async {
      final prefs = FakeLocalPrefs();
      final pending = prefs.update((d) => d.copyWith(hapticsEnabled: false));
      expect(prefs.data.hapticsEnabled, isFalse);
      await pending;
      expect(prefs.updates, 1);

      await prefs.clear();
      expect(prefs.data, LocalPrefsData.defaults);
      expect(prefs.clears, 1);
    },
  );
}

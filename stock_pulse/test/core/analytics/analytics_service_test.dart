import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';

import '../../helpers/fake_crash_reporter.dart';

class Sink implements AnalyticsSink {
  final events = <AnalyticsEvent>[];
  bool fail = false;
  int resets = 0;
  final properties = <String, String?>{};
  @override
  String get id => 'test';
  @override
  Future<void> log(AnalyticsEvent event) async {
    if (fail) throw StateError('sink');
    events.add(event);
  }

  @override
  Future<void> reset() async {
    resets++;
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    properties[name] = value;
  }
}

void main() {
  test(
    'consent gates every sink; a failed sink does not block others',
    () async {
      var consent = false;
      final broken = Sink()..fail = true;
      final good = Sink();
      final reporter = FakeCrashReporter();
      final service = AnalyticsService(
        [broken, good],
        reporter,
        consent: () => consent,
      );
      const event = AnalyticsEvent('screen_view', {'screen': 'watchlist'});
      service.log(event);
      await Future<void>.delayed(Duration.zero);
      expect(good.events, isEmpty);
      consent = true;
      service.log(event);
      await Future<void>.delayed(Duration.zero);
      expect(good.events, [event]);
      await service.reset();
      expect(good.resets, 1);
    },
  );
  test('event validation rejects PII-shaped payloads and invalid names', () {
    expect(const AnalyticsEvent('Bad name').isValid, isFalse);
    expect(
      const AnalyticsEvent('question', {'prompt': 'private text'}).isValid,
      isFalse,
    );
    expect(
      const AnalyticsEvent('screen_view', {'screen': 'watchlist'}).isValid,
      isTrue,
    );
  });

  test(
    'analytics contract fans out screen and user properties only with consent',
    () async {
      final sink = Sink();
      final service = AnalyticsService(
        [sink],
        FakeCrashReporter(),
        consent: () => true,
      );
      service.setScreen('watchlist');
      await service.setUserProperty('theme', 'dark');
      await service.setUserProperty('account_id', 'private');
      await pumpEventQueue();
      expect(sink.events.single.name, 'screen_view');
      expect(sink.events.single.params, {'screen': 'watchlist'});
      expect(sink.properties, {'theme': 'dark'});
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/data/debug_analytics_sink.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';

void main() {
  test(
    'analytics event accepts safe scalar parameters and compares by value',
    () {
      const event = AnalyticsEvent('order_placed', {'side': 'buy', 'qty': 2});
      const equal = AnalyticsEvent('order_placed', {'side': 'buy', 'qty': 2});
      expect(event.isValid, isTrue);
      expect(event, equal);
      expect(event.hashCode, equal.hashCode);
      expect(const AnalyticsEvent('bad name').isValid, isFalse);
      expect(
        const AnalyticsEvent('safe', {'message': 'private'}).isValid,
        isFalse,
      );
      expect(
        const AnalyticsEvent('ai_question', {
          'intent': 'why is this down?',
        }).isValid,
        isFalse,
      );
      expect(
        const AnalyticsEvent('safe', {'x': double.infinity}).isValid,
        isFalse,
      );
      expect(
        AnalyticsEvent('safe', {for (var i = 0; i < 26; i++) 'p$i': i}).isValid,
        isFalse,
      );
    },
  );

  test('debug sink caps history at 200 and reset clears it', () async {
    final sink = DebugAnalyticsSink();
    expect(sink.id, 'debug');
    for (var i = 0; i < 201; i++) {
      await sink.log(AnalyticsEvent('event_$i'));
    }
    expect(sink.events, hasLength(200));
    expect(sink.events.first.name, 'event_1');
    await sink.setUserProperty('mode', 'demo');
    await sink.reset();
    expect(sink.events, isEmpty);
  });

  test(
    'the event catalogue contains only valid events and safe parameters',
    () {
      final events = [
        Events.appOpened(launch: 'cold', firstFrameMs: 140),
        Events.screenView('watchlist'),
        Events.screenView('/stock/RELIANCE'),
        Events.deepLinkOpened('/stock/:id', 'app'),
        Events.orderSubmitted(
          kind: 'equity',
          product: 'delivery',
          source: 'watchlist',
        ),
        Events.alertCreated('above'),
        Events.aiQuestionAsked('quote'),
        Events.watchlistRowAction(action: 'open', instrumentKind: 'equity'),
        Events.errorShown('network'),
        Events.alertOpened(),
        Events.chartOpened,
        Events.chartSettingChanged('range', '1d'),
        Events.studyAdded('rsi'),
        Events.studyRemoved('rsi'),
        Events.drawingAdded('trend_line'),
        Events.chartFullscreen,
        Events.orderSheetOpened('chain'),
        Events.orderConfirmTapped('option'),
        Events.orderResult('filled', 'ok'),
        Events.orderBlockedStale,
        Events.riskNoticeShown,
        Events.riskNoticeAck,
        Events.aiQuestion('pcr'),
        Events.aiCardAction('open_chain'),
        Events.pushOpened('alert'),
        Events.connectionChanged('live'),
      ];
      expect(events.every((event) => event.isValid), isTrue);
      expect(events[2].params['screen'], '/stock/:id');
    },
  );
}

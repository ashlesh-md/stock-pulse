import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';

abstract final class Events {
  static AnalyticsEvent appOpened({
    required String launch,
    required int firstFrameMs,
  }) => AnalyticsEvent('app_open', {
    'launch': launch,
    'first_frame_ms': firstFrameMs,
  });
  static AnalyticsEvent screenView(String screen) =>
      AnalyticsEvent('screen_view', {'screen': _pathPattern(screen)});
  static AnalyticsEvent deepLinkOpened(String path, String via) =>
      AnalyticsEvent('deep_link_opened', {
        'path': _pathPattern(path),
        'via': via,
      });
  static AnalyticsEvent orderSubmitted({
    required String kind,
    required String product,
    required String source,
  }) => AnalyticsEvent('order_submitted', {
    'kind': kind,
    'product': product,
    'source': source,
  });
  static AnalyticsEvent alertCreated(String condition) =>
      AnalyticsEvent('alert_created', {'condition': condition});
  static AnalyticsEvent aiQuestionAsked(String intent) =>
      AnalyticsEvent('ai_question_asked', {'intent': intent});
  static AnalyticsEvent watchlistRowAction({
    required String action,
    required String instrumentKind,
  }) => AnalyticsEvent('watchlist_row_action', {
    'action': action,
    'instrument_kind': instrumentKind,
  });
  static AnalyticsEvent errorShown(String code) =>
      AnalyticsEvent('error_shown', {'code': code});
  static AnalyticsEvent alertOpened() =>
      const AnalyticsEvent('alert_opened', {'source': 'banner'});
  static const chartOpened = AnalyticsEvent('chart_opened');
  static AnalyticsEvent chartSettingChanged(String setting, String value) =>
      AnalyticsEvent('chart_setting_changed', {
        'setting': setting,
        'value': value,
      });
  static AnalyticsEvent studyAdded(String kind) =>
      AnalyticsEvent('study_added', {'kind': kind});
  static AnalyticsEvent studyRemoved(String kind) =>
      AnalyticsEvent('study_removed', {'kind': kind});
  static AnalyticsEvent drawingAdded(String kind) =>
      AnalyticsEvent('drawing_added', {'kind': kind});
  static const chartFullscreen = AnalyticsEvent('chart_fullscreen');
  static AnalyticsEvent orderSheetOpened(String source) =>
      AnalyticsEvent('order_sheet_opened', {'source': source});
  static AnalyticsEvent orderConfirmTapped(String kind) =>
      AnalyticsEvent('order_confirm_tapped', {'kind': kind});
  static AnalyticsEvent orderResult(String result, String code) =>
      AnalyticsEvent('order_result', {'result': result, 'code': code});
  static const orderBlockedStale = AnalyticsEvent('order_blocked_stale');
  static const riskNoticeShown = AnalyticsEvent('risk_notice_shown');
  static const riskNoticeAck = AnalyticsEvent('risk_notice_ack');
  static AnalyticsEvent aiQuestion(String intent) =>
      AnalyticsEvent('ai_question', {'intent': intent});
  static AnalyticsEvent aiCardAction(String action) =>
      AnalyticsEvent('ai_card_action', {'action': action});
  static AnalyticsEvent pushOpened(String type) =>
      AnalyticsEvent('push_opened', {'type': type});
  static AnalyticsEvent connectionChanged(String status) =>
      AnalyticsEvent('connection_changed', {'status': status});

  static String _pathPattern(String path) {
    final segments = path.split('/');
    if (segments.length == 3 && segments[1] == 'stock') {
      return '/stock/:id';
    }
    if (segments.length == 3 && segments[1] == 'order') {
      return '/order/:id';
    }
    return path;
  }
}

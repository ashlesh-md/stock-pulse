import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/deep_link.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';

class PushLinkHandler {
  PushLinkHandler(
    this._service,
    this._router,
    this._analytics,
    this._reporter, {
    this.onForegroundMessage,
    this.onInvalidLink,
    this.alertAlreadySeen,
  });
  final PushService _service;
  final GoRouter _router;
  final AnalyticsService _analytics;
  final CrashReporter _reporter;
  final void Function(PushMessage message, String? path)? onForegroundMessage;
  final void Function()? onInvalidLink;
  final bool Function(String alertId)? alertAlreadySeen;
  StreamSubscription<PushMessage>? _taps;
  StreamSubscription<PushMessage>? _foreground;
  bool _disposed = false;
  final Set<String> _seen = {};
  Future<void> start() async {
    _taps = _service.onTap.listen(
      _open,
      onError: (Object error, StackTrace stack) =>
          _reporter.recordError(error, stack, reason: 'push_stream'),
    );
    _foreground = _service.onForeground.listen(
      _showForeground,
      onError: (Object error, StackTrace stack) =>
          _reporter.recordError(error, stack, reason: 'push_foreground_stream'),
    );
    try {
      await _service.init();
      await _service.token();
      final initial = await _service.initialMessage();
      if (!_disposed && initial != null) _open(initial);
    } on Object catch (error, stack) {
      _reporter.recordError(error, stack, reason: 'push_unavailable');
    }
  }

  void _showForeground(PushMessage message) {
    if (_disposed) return;
    if (message.type == PushMessageType.alert &&
        (alertAlreadySeen?.call(message.id) ?? false)) {
      return;
    }
    final link = message.link;
    final path = link == null ? null : normaliseLink(link)?.toString();
    onForegroundMessage?.call(message, path);
  }

  void _open(PushMessage message) {
    if (_disposed || !_seen.add(message.id)) return;
    if (_seen.length > 500) _seen.remove(_seen.first);
    final link = message.link;
    if (link == null) {
      _reporter.log('push_ignored');
      return;
    }
    final uri = normaliseLink(link);
    if (uri == null) {
      _reporter.log('push_link_refused');
      onInvalidLink?.call();
      _router.go(WatchlistRoute.path);
      return;
    }
    _analytics.log(Events.deepLinkOpened(uri.path, 'push'));
    _analytics.log(Events.pushOpened(message.type.name));
    _router.go(uri.toString());
  }

  Future<void> dispose() async {
    _disposed = true;
    await _taps?.cancel();
    await _foreground?.cancel();
  }
}

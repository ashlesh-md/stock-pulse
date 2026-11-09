import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';

/// Holds the one message on screen (state) and one waiting message.
/// Only application controllers call [show]; `FeedbackHost` renders the
/// state and reports [dismissed] and [actionTapped].
final class FeedbackController extends Notifier<FeedbackMessage?> {
  /// A key shown less than this long ago is dropped.
  static const repeatWindow = Duration(seconds: 4);

  late Clock _clock;
  final _lastShownAt = <String, DateTime>{};
  final _replies = StreamController<FeedbackReply>.broadcast();
  FeedbackMessage? _waiting;

  /// The lower-priority message shown when the current one closes.
  FeedbackMessage? get waiting => _waiting;

  /// [ReplyToSender] taps; senders filter by their key prefix.
  Stream<FeedbackReply> get replies => _replies.stream;

  @override
  FeedbackMessage? build() {
    _clock = ref.watch(clockProvider);
    ref.onDispose(_replies.close);
    return null;
  }

  void show(FeedbackMessage message) {
    final current = state;
    if (current?.key == message.key || _shownRecently(message.key)) return;
    if (current == null || message.priority.index >= current.priority.index) {
      _display(message);
    } else {
      _waiting = message;
    }
  }

  void dismissed(String key) {
    if (state?.key != key) return;
    final next = _waiting;
    _waiting = null;
    state = null;
    if (next != null) _display(next);
  }

  void clear() {
    _waiting = null;
    state = null;
  }

  void actionTapped(FeedbackMessage message) {
    if (message.action case ReplyToSender(:final actionId)) {
      _replies.add(FeedbackReply(key: message.key, actionId: actionId));
    }
  }

  void _display(FeedbackMessage message) {
    final now = _clock.now();
    _lastShownAt
      ..removeWhere((_, at) => now.difference(at) >= repeatWindow)
      ..[message.key] = now;
    if (message.kind == FeedbackKind.error) {
      final parts = message.key.split('.');
      final code = parts.length > 1 ? parts[1] : 'unknown';
      ref.read(analyticsProvider).log(Events.errorShown(code));
    }
    state = message;
  }

  bool _shownRecently(String key) {
    final at = _lastShownAt[key];
    return at != null && _clock.now().difference(at) < repeatWindow;
  }
}

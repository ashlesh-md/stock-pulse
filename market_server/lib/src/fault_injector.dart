import 'package:market_server/src/http_helpers.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:shelf/shelf.dart';

/// One queued fault from `POST /debug/faults`.
class FaultPlan {
  FaultPlan({
    required this.path,
    required this.method,
    this.delay = Duration.zero,
    this.status,
    this.dropAckAfterStore = false,
    this.count = 1,
  });

  /// Returns null when [json] has no `path`.
  static FaultPlan? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;
    return FaultPlan(
      path: path,
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      delay: Duration(milliseconds: (json['delayMs'] as num? ?? 0).toInt()),
      status: (json['status'] as num?)?.toInt(),
      dropAckAfterStore: json['dropAckAfterStore'] == true,
      count: (json['count'] as num? ?? 1).toInt(),
    );
  }

  /// A path prefix such as `/api/v1/orders`.
  final String path;
  final String method;
  final Duration delay;
  final int? status;
  final bool dropAckAfterStore;

  /// Requests left to hit.
  int count;

  bool matches(Request request) =>
      request.method == method && '/${request.url.path}'.startsWith(path);
}

/// Holds queued faults; [faultInjection] applies them.
class FaultInjector {
  final _plans = <FaultPlan>[];

  /// How long a dropped ack waits when the plan gives no delay: longer
  /// than the app's request timeout.
  static const dropAckWait = Duration(seconds: 20);

  void add(FaultPlan plan) {
    if (plan.count > 0) _plans.add(plan);
  }

  void clear() => _plans.clear();

  int get pending => _plans.length;

  FaultPlan? take(Request request) {
    for (final plan in _plans) {
      if (!plan.matches(request)) continue;
      if (--plan.count <= 0) _plans.remove(plan);
      return plan;
    }
    return null;
  }
}

/// Delays, fails or drops the reply of requests that match a queued plan.
Middleware faultInjection(FaultInjector faults, MarketClock clock) =>
    (Handler inner) => (Request request) async {
      final plan = faults.take(request);
      if (plan == null) return inner(request);
      if (plan.dropAckAfterStore) {
        await inner(request);
        await clock.delay(
          plan.delay == Duration.zero ? FaultInjector.dropAckWait : plan.delay,
        );
        return errorResponse(504, 'ack_dropped', 'ack_dropped');
      }
      if (plan.delay > Duration.zero) await clock.delay(plan.delay);
      final status = plan.status;
      if (status != null) {
        return errorResponse(status, 'fault_injected', 'fault_injected');
      }
      return inner(request);
    };

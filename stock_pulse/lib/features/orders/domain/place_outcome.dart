import 'package:stock_pulse/features/orders/domain/order.dart';

/// Result of ONE `OrderRepository.place` attempt. The ticket retries a
/// [PlaceTimedOut] with the same key (≤ 2).
sealed class PlaceOutcome {
  const PlaceOutcome();
}

final class PlaceAcked extends PlaceOutcome {
  const PlaceAcked(this.order);
  final Order order;
}

/// 4xx with a `code`, e.g. `price_band`, `insufficient_funds`.
final class PlaceRejected extends PlaceOutcome {
  const PlaceRejected(this.code, this.message);
  final String code;
  final String message;
}

/// Timeout, network failure or 5xx: the order may or may not exist.
final class PlaceTimedOut extends PlaceOutcome {
  const PlaceTimedOut();
}

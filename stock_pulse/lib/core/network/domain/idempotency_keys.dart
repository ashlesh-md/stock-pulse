/// Makes the `Idempotency-Key` for a write the server must apply once, so a
/// retry after a timeout does not place an order or credit funds twice.
abstract interface class IdempotencyKeys {
  String next();
}

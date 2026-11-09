import 'dart:math';

import 'package:stock_pulse/core/network/domain/idempotency_keys.dart';

/// 16 random bytes from a secure source, as 32 hex characters.
class SecureIdempotencyKeys implements IdempotencyKeys {
  SecureIdempotencyKeys([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next() => [
    for (var i = 0; i < 16; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

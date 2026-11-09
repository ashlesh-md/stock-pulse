import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/secure_idempotency_keys.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';

void main() {
  test('a key is 32 lowercase hex characters and keys differ', () {
    final keys = SecureIdempotencyKeys(Random(1));
    final a = keys.next();
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(keys.next(), isNot(a));
  });

  test('the provider gives a secure generator', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(idempotencyKeysProvider),
      isA<SecureIdempotencyKeys>(),
    );
    expect(container.read(idempotencyKeysProvider).next(), hasLength(32));
  });
}

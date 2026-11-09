import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

void main() {
  final json = {
    'code': '2026-11-10',
    'expiryAt': DateTime.utc(2026, 11, 10, 10).millisecondsSinceEpoch,
    'kind': 'weekly',
  };

  test('fromJson reads the expiry; isToday defaults to false', () {
    final e = Expiry.fromJson(json);
    expect(e.code, '2026-11-10');
    expect(e.expiryAt, DateTime.utc(2026, 11, 10, 10));
    expect(e.kind, ExpiryKind.weekly);
    expect(e.isToday, isFalse);
  });

  test('equal by value', () {
    final today = Expiry.fromJson({...json, 'isToday': true});
    expect(Expiry.fromJson(json), Expiry.fromJson(json));
    expect(Expiry.fromJson(json).hashCode, Expiry.fromJson(json).hashCode);
    expect(today, isNot(Expiry.fromJson(json)));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

Map<String, Object?> alertJson({String status = 'active', int version = 1}) => {
  'alertId': 'A1',
  'symbol': 'TCS',
  'cond': 'above',
  'level': 3100,
  'status': status,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'version': version,
};

void main() {
  test('fromJson reads an active alert', () {
    final a = PriceAlert.fromJson(alertJson());
    expect(a.cond, AlertCondition.above);
    expect(a.level, 3100);
    expect(a.status, AlertStatus.active);
    expect(a.triggeredAt, isNull);
    expect(a.triggerLtp, isNull);
  });

  test('fromJson reads the trigger time and price', () {
    final a = PriceAlert.fromJson(
      {
        ...alertJson(status: 'triggered'),
        'triggeredAt': '2026-11-10T05:00:00.000Z',
        'triggerLtp': 3101.5,
      }..remove('version'),
    );
    expect(a.triggeredAt, DateTime.utc(2026, 11, 10, 5));
    expect(a.triggerLtp, 3101.5);
    expect(a.version, 0);
  });

  test('equal by id, status, level and version', () {
    final a = PriceAlert.fromJson(alertJson());
    expect(a, PriceAlert.fromJson(alertJson()));
    expect(a.hashCode, PriceAlert.fromJson(alertJson()).hashCode);
    expect(a, isNot(PriceAlert.fromJson(alertJson(version: 2))));
  });
}

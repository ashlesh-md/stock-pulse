import 'package:meta/meta.dart';

/// One enum with the server.
enum AlertCondition { above, below }

enum AlertStatus { active, triggered, cancelled }

/// A one-shot price alert.
@immutable
class PriceAlert {
  const PriceAlert({
    required this.alertId,
    required this.symbol,
    required this.cond,
    required this.level,
    required this.status,
    required this.createdAt,
    this.triggeredAt,
    this.triggerLtp,
    this.version = 0,
  });

  factory PriceAlert.fromJson(Map<String, Object?> j) {
    final triggeredAt = j['triggeredAt'] as String?;
    return PriceAlert(
      alertId: j['alertId']! as String,
      symbol: j['symbol']! as String,
      cond: AlertCondition.values.byName(j['cond']! as String),
      level: (j['level']! as num).toDouble(),
      status: AlertStatus.values.byName(j['status']! as String),
      createdAt: DateTime.parse(j['createdAt']! as String),
      triggeredAt: triggeredAt == null ? null : DateTime.parse(triggeredAt),
      triggerLtp: (j['triggerLtp'] as num?)?.toDouble(),
      version: j['version'] as int? ?? 0,
    );
  }

  final String alertId;
  final String symbol;
  final AlertCondition cond;
  final double level;
  final AlertStatus status;

  /// Market time.
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final double? triggerLtp;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is PriceAlert &&
      other.alertId == alertId &&
      other.status == status &&
      other.level == level &&
      other.version == version;

  @override
  int get hashCode => Object.hash(alertId, status, level, version);
}

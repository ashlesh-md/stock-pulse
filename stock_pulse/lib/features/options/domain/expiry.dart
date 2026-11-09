/// Weekly (NIFTY) or monthly (stocks).
enum ExpiryKind { weekly, monthly }

class Expiry {
  const Expiry({
    required this.code,
    required this.expiryAt,
    required this.kind,
    required this.isToday,
  });

  factory Expiry.fromJson(Map<String, Object?> j) => Expiry(
    code: j['code']! as String,
    expiryAt: DateTime.fromMillisecondsSinceEpoch(
      j['expiryAt']! as int,
      isUtc: true,
    ),
    kind: ExpiryKind.values.byName(j['kind']! as String),
    isToday: j['isToday'] as bool? ?? false,
  );

  /// e.g. `2026-11-10`.
  final String code;

  /// 15:30 IST on the expiry day (market time).
  final DateTime expiryAt;
  final ExpiryKind kind;
  final bool isToday;

  @override
  bool operator ==(Object other) =>
      other is Expiry &&
      other.code == code &&
      other.expiryAt == expiryAt &&
      other.kind == kind &&
      other.isToday == isToday;

  @override
  int get hashCode => Object.hash(code, expiryAt, kind, isToday);
}

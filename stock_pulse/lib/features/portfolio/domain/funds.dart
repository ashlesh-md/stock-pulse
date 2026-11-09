import 'package:meta/meta.dart';

@immutable
class Funds {
  const Funds({required this.available, this.version = 0});

  factory Funds.fromJson(Map<String, Object?> j) => Funds(
    available: (j['available']! as num).toDouble(),
    version: j['version'] as int? ?? 0,
  );

  final double available;
  final int version;

  Map<String, Object?> toJson() => {'available': available, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is Funds &&
      other.available == available &&
      other.version == version;

  @override
  int get hashCode => Object.hash(available, version);
}

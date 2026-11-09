import 'package:intl/intl.dart';

/// Picks the plural form of [n] by the current `Intl` locale's rules.
String plural(
  int n, {
  required String one,
  required String other,
  String? zero,
}) => Intl.plural(n, zero: zero, one: one, other: other);

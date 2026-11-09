/// Price rounded to 2 dp for the wire.
double r2(num v) => (v * 100).roundToDouble() / 100;

/// `₹`-less Indian grouping: 1,23,456 or 1,412.35 (2 dp only when needed).
String formatInr(num v) {
  final neg = v < 0;
  final abs = r2(v.abs());
  final whole = abs.truncate();
  final frac = ((abs - whole) * 100).round();
  final digits = '$whole';
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  final text = frac == 0 ? grouped : '$grouped.${'$frac'.padLeft(2, '0')}';
  return neg ? '−$text' : text;
}

/// Signed percentage with a real minus sign: +1.20%, −0.40%.
String formatPct(num v) {
  final s = r2(v.abs()).toStringAsFixed(2);
  return v < 0 ? '−$s%' : '+$s%';
}

/// "2026-11-10" → "10 Nov".
String formatExpiry(String expiry) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = DateTime.parse(expiry);
  return '${d.day} ${months[d.month - 1]}';
}

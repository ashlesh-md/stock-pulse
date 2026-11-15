const _plain = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _accented = 'åƀçðéƒĝĥîĵķļɱñöþǫŕšţûṽŵẋýžÅƁÇÐÉƑĜĤÎĴĶĻṀÑÖÞǪŔŠŢÛṼŴẊÝŽ';

/// [text] with every ASCII letter accented and padded to about 140 % of
/// its length inside `[` `]`, so clipped, truncated or hard-coded text
/// stands out on screen. Empty text stays empty.
String pseudo(String text) {
  if (text.isEmpty) return text;
  final accented = String.fromCharCodes(
    text.codeUnits.map((unit) {
      final at = _plain.indexOf(String.fromCharCode(unit));
      return at < 0 ? unit : _accented.codeUnitAt(at);
    }),
  );
  final padding = '·' * ((text.length * 0.4).ceil() - 2).clamp(0, text.length);
  return '[$accented$padding]';
}

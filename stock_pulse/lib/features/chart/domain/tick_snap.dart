double snapToTick(double price, double tickSize) {
  if (!price.isFinite || !tickSize.isFinite || tickSize <= 0) {
    throw ArgumentError(
      'Price and tick size must be finite; tick size positive',
    );
  }
  return double.parse(
    ((price / tickSize).round() * tickSize).toStringAsFixed(8),
  );
}

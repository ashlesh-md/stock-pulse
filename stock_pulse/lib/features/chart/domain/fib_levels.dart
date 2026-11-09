/// Fibonacci retracement ratios and their interpolated price values.
const bool fibToolReady = true;

const fibRatios = <double>[0, .236, .382, .5, .618, 1];

List<FibLevel> fibLevels(double start, double end) => [
  for (final ratio in fibRatios)
    FibLevel(ratio: ratio, price: start + (end - start) * ratio),
];

class FibLevel {
  const FibLevel({required this.ratio, required this.price});

  final double ratio;
  final double price;

  String get label => '${(ratio * 100).toStringAsFixed(1)}%';

  @override
  bool operator ==(Object other) =>
      other is FibLevel && other.ratio == ratio && other.price == price;

  @override
  int get hashCode => Object.hash(ratio, price);
}

/// Order-outcome haptics. Selection clicks are not here: they use
/// `HapticFeedback.selectionClick()`.
abstract interface class Haptics {
  Future<void> success();
  Future<void> rejection();
}

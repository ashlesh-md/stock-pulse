import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Height of the chat's bottom dock (follow-up chips and composer, safe area
/// included), so the floating tab shortcut can rest just above it.
class ChatDockHeight extends Notifier<double> {
  @override
  double build() => 0;

  void set(double height) => state = height;
}

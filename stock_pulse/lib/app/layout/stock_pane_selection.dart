import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The stock shown in the watchlist's detail pane on expanded windows; null
/// until one is picked.
class StockPaneSelection extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String instrumentId) => state = instrumentId;
}

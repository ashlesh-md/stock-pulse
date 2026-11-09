import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/app/layout/chat_dock_height.dart';
import 'package:stock_pulse/app/layout/stock_pane_selection.dart';

final stockPaneProvider = NotifierProvider<StockPaneSelection, String?>(
  StockPaneSelection.new,
);

final chatDockHeightProvider = NotifierProvider<ChatDockHeight, double>(
  ChatDockHeight.new,
);

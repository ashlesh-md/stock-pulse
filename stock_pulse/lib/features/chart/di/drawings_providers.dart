import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/application/drawings/drawings_controller.dart';
import 'package:stock_pulse/features/chart/application/drawings/drawings_state.dart';

final drawingsControllerProvider =
    NotifierProvider.family<DrawingsController, DrawingsState, String>(
      DrawingsController.new,
    );

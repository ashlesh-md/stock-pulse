import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/more/application/demo_controller.dart';

final demoControllerProvider =
    NotifierProvider<DemoController, AsyncValue<void>>(DemoController.new);

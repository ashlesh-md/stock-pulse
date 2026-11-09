import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/features/more/application/socket_lab_controller.dart';
import 'package:stock_pulse/features/more/application/socket_lab_state.dart';

final socketLabControllerProvider =
    NotifierProvider.autoDispose<SocketLabController, SocketLabState>(
      SocketLabController.new,
    );

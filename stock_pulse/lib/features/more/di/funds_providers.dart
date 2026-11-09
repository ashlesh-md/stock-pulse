import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/features/more/application/add_funds_controller.dart';
import 'package:stock_pulse/features/more/application/add_funds_state.dart';

/// Not auto-disposed: an uncertain transfer keeps its idempotency key when
/// the screen is closed and reopened, so a retry never credits twice.
final addFundsControllerProvider =
    NotifierProvider<AddFundsController, AddFundsState>(AddFundsController.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/options/application/chain_controller.dart';
import 'package:stock_pulse/features/options/application/chain_state.dart';

final chainControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChainController, ChainState, ({String underlying, String? expiry})>(
      ChainController.new,
    );

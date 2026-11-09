import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/more/data/debug_api.dart';
import 'package:stock_pulse/features/more/data/funds_transfer_api.dart';
import 'package:stock_pulse/features/more/domain/chaos_trigger.dart';
import 'package:stock_pulse/features/more/domain/funds_transfer.dart';

final fundsTransferProvider = Provider<FundsTransfer>(
  (ref) => FundsTransferApi(ref.watch(apiClientProvider)),
);

final chaosTriggerProvider = Provider<ChaosTrigger>(
  (ref) => DebugChaosTrigger(ref.watch(apiClientProvider)),
);

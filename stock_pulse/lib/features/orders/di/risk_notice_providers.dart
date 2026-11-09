import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/orders/application/risk_notice_controller.dart';

final riskNoticeProvider = AsyncNotifierProvider<RiskNoticeController, bool>(
  RiskNoticeController.new,
);

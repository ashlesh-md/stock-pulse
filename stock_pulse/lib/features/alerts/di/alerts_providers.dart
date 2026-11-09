import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/alerts/application/alerts_controller.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

final alertsControllerProvider =
    StreamNotifierProvider.autoDispose<AlertsController, List<PriceAlert>>(
      AlertsController.new,
    );

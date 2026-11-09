import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/alerts/application/alert_queue.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

final alertQueueProvider = NotifierProvider<AlertQueue, List<PriceAlert>>(
  AlertQueue.new,
);

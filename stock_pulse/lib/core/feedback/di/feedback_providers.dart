import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/feedback/application/feedback_controller.dart';
import 'package:stock_pulse/core/feedback/application/open_sheet_count.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';

final feedbackControllerProvider =
    NotifierProvider<FeedbackController, FeedbackMessage?>(
      FeedbackController.new,
    );

final openSheetCountProvider = NotifierProvider<OpenSheetCount, int>(
  OpenSheetCount.new,
);

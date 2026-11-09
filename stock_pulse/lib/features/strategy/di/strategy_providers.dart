import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_controller.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_state.dart';
import 'package:stock_pulse/features/strategy/application/strategy_draft_controller.dart';
import 'package:stock_pulse/features/strategy/application/strategy_draft_state.dart';

/// Keep-alive: the draft must survive the builder and chain screens closing.
final strategyDraftControllerProvider =
    NotifierProvider<StrategyDraftController, StrategyDraft>(
      StrategyDraftController.new,
    );

final strategyBuilderControllerProvider =
    AsyncNotifierProvider.autoDispose<
      StrategyBuilderController,
      StrategyBuilderState
    >(StrategyBuilderController.new);

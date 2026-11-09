import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/platform/di/platform_providers.dart';
import 'package:stock_pulse/core/platform/domain/haptic_dedupe.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/application/order_summary.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

/// Shows a snackbar when an order changes after it was placed: a limit
/// order filling minutes later, or a cancel. A market order that filled at
/// once is skipped: the order sheet already said so.
class OrderAnnouncer extends Notifier<void> {
  final HapticDedupe _dedupe = HapticDedupe();
  final List<Order> _pending = [];
  bool _seeded = false;

  @override
  void build() {
    final repository = ref.watch(portfolioRepositoryProvider);
    final sub = repository.orderUpdates.listen(_onUpdate);
    ref.onDispose(sub.cancel);
    unawaited(_seed(repository));
  }

  Future<void> _seed(PortfolioRepository repository) async {
    try {
      final result = await repository.getOrders();
      if (!ref.mounted) return;
      if (result case Success(value: final orders)) {
        _dedupe.seed(
          orders
              .where((order) => _isTerminal(order.status))
              .map((order) => (order.id, order.status.name)),
        );
      }
    } on Object catch (_) {
      // A failed seed must not prevent live order outcomes from being shown.
    }
    if (!ref.mounted) return;
    _seeded = true;
    for (final order in _pending) {
      _announce(order);
    }
    _pending.clear();
  }

  static bool shouldAnnounce(Order o) =>
      (o.status == OrderStatus.complete ||
          o.status == OrderStatus.cancelled ||
          o.status == OrderStatus.rejected) &&
      o.updatedAt.isAfter(o.createdAt);

  static bool _isTerminal(OrderStatus status) =>
      status == OrderStatus.complete ||
      status == OrderStatus.cancelled ||
      status == OrderStatus.rejected;

  void _onUpdate(Order order) {
    if (!_seeded) {
      _pending.add(order);
      return;
    }
    _announce(order);
  }

  void _announce(Order order) {
    if (!shouldAnnounce(order)) return;
    if (!_dedupe.firstTime((order.id, order.status.name))) return;
    final strings = ref.read(stringsProvider).orders;
    final rejected = order.status == OrderStatus.rejected;
    ref
        .read(feedbackControllerProvider.notifier)
        .show(
          FeedbackMessage(
            key: 'orders.${order.status.name}.${order.id}',
            text: strings.withId(order.id, orderSummary(order, strings)),
            kind: switch (order.status) {
              OrderStatus.pending => FeedbackKind.info,
              OrderStatus.complete => FeedbackKind.success,
              OrderStatus.rejected => FeedbackKind.error,
              OrderStatus.queued ||
              OrderStatus.triggerPending ||
              OrderStatus.open ||
              OrderStatus.cancelled => FeedbackKind.info,
            },
            persist: rejected,
            priority: FeedbackPriority.orderOutcome,
          ),
        );
    if (order.status == OrderStatus.complete ||
        order.status == OrderStatus.rejected) {
      unawaited(_playOutcomeHaptic(order.status));
    }
  }

  Future<void> _playOutcomeHaptic(OrderStatus status) async {
    try {
      final prefs = await ref.read(localPrefsProvider.future);
      if (!ref.mounted || !prefs.data.hapticsEnabled) return;
      final haptics = ref.read(hapticsProvider);
      if (status == OrderStatus.complete) {
        await haptics.success();
      } else {
        await haptics.rejection();
      }
    } on Object catch (_) {
      // Haptic failures should never suppress the already-shown outcome.
    }
  }
}

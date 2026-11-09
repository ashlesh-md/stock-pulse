import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;

/// Pinned bottom of the order sheet: the send failure, the reason Confirm
/// is disabled, and the side-coloured Confirm that repeats the order.
class OrderConfirmBar extends StatelessWidget {
  const OrderConfirmBar({
    super.key,
    required this.symbol,
    required this.draft,
    this.blockReason,
    this.checkingStatus = false,
    required this.onConfirm,
  });

  final String symbol;
  final OrderDraft draft;
  final String? blockReason;
  final bool checkingStatus;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final s = context.strings.orders;
    final buy = draft.side == OrderSide.buy;
    final error = draft.error;
    final validationBlocked = draft.issues.isNotEmpty;
    final blocked = validationBlocked || blockReason != null;
    final amount = draft.inLots
        ? context.strings.common.lots(draft.count ?? 0)
        : '${draft.count ?? 0}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpSpace.s5,
        SpSpace.s2,
        SpSpace.s5,
        SpSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Container(
                margin: const EdgeInsets.only(bottom: SpSpace.s2),
                padding: const EdgeInsets.all(SpSpace.s3),
                decoration: BoxDecoration(
                  color: sp.downTint,
                  borderRadius: BorderRadius.circular(SpRadius.m),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.error, size: 16, color: sp.down),
                    const SizedBox(width: SpSpace.s2),
                    Expanded(
                      child: Text(error, style: TextStyle(color: sp.down)),
                    ),
                  ],
                ),
              ),
            ),
          if (blocked && error == null)
            Padding(
              padding: const EdgeInsets.only(bottom: SpSpace.s2),
              child: Text(
                validationBlocked ? s.fixFields : blockReason!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: sp.textSecondary),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: buy ? sp.buy : sp.sell,
              foregroundColor: buy ? sp.onAccent : sp.onSell,
              minimumSize: const Size.fromHeight(SpDensity.confirm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SpRadius.m),
              ),
            ),
            onPressed: draft.submitting || blocked ? null : onConfirm,
            child: draft.submitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: SpSpace.s2),
                      Text(checkingStatus ? s.checkingStatus : s.placing),
                    ],
                  )
                : Text(
                    s.confirmLabel(buy ? s.buy : s.sell, amount, symbol),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}

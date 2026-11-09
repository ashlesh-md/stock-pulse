import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/features/orders/di/risk_notice_providers.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/risk_notice_panel.dart';

class OptionRiskGate extends ConsumerWidget {
  const OptionRiskGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(riskNoticeProvider)) {
        AsyncData(value: true) => child,
        AsyncData() => RiskNoticePanel(
          onContinue: () => ref.read(riskNoticeProvider.notifier).acknowledge(),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(riskNoticeProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
}

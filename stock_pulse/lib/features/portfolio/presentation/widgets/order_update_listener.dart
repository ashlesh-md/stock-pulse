import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';

/// Keeps the order announcer alive above every route, so later fills and
/// cancels show a snackbar on any screen.
class OrderUpdateListener extends ConsumerWidget {
  const OrderUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(orderAnnouncerProvider);
    return child;
  }
}

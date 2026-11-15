import 'package:flutter/material.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';

class ChartExpandButton extends StatelessWidget {
  const ChartExpandButton({super.key, required this.instrumentId});
  final String instrumentId;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.strings.chart.expand,
    icon: const Icon(AppIcons.expand),
    onPressed: () => context.pushTo(ChartRoute(instrumentId)),
  );
}

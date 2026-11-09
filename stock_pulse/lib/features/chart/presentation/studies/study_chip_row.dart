import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class StudyChipRow extends ConsumerWidget {
  const StudyChipRow({
    super.key,
    required this.instrumentId,
    this.interval = CandleInterval.m5,
    this.series = const {},
  });
  final String instrumentId;
  final CandleInterval interval;
  final Map<StudySpec, StudySeries> series;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studies = ref.watch(studiesControllerProvider(instrumentId));
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < studies.length; i++)
          InputChip(
            label: Text(_label(context, studies[i])),
            deleteButtonTooltipMessage: context.strings.studies.remove,
            onDeleted: () => ref
                .read(studiesControllerProvider(instrumentId).notifier)
                .remove(i),
          ),
      ],
    );
  }

  String _label(BuildContext context, StudySpec spec) {
    final strings = context.strings.studies;
    if (spec.kind.name == 'vwap' && !interval.isIntraday) {
      return strings.intradayOnly;
    }
    if (series[spec]?.notEnoughData == true) {
      final label = strings.name(spec.kind.name);
      final suffix = spec.kind.name == 'vwap' ? '' : '(${spec.period})';
      return strings.notEnough('$label$suffix');
    }
    final suffix = spec.kind.name == 'vwap' ? '' : ' (${spec.period})';
    return '${strings.name(spec.kind.name)}$suffix';
  }
}

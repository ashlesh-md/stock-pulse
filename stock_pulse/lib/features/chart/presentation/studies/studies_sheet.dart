import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/chart/application/studies/studies_controller.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_catalog.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

Future<void> showStudiesSheet(BuildContext context, String instrumentId) =>
    showSpSheet<void>(
      context,
      builder: (_) => StudiesSheet(instrumentId: instrumentId),
    );

class StudiesSheet extends ConsumerStatefulWidget {
  const StudiesSheet({super.key, required this.instrumentId});
  final String instrumentId;
  @override
  ConsumerState<StudiesSheet> createState() => _StudiesSheetState();
}

class _StudiesSheetState extends ConsumerState<StudiesSheet> {
  StudyKind _kind = StudyKind.sma;
  int _period = 20;
  @override
  Widget build(BuildContext context) {
    final s = context.strings.studies;
    final studies = ref.watch(studiesControllerProvider(widget.instrumentId));
    final defaultSpec = StudyCatalog.defaultFor(_kind);
    final selected = StudySpec(
      kind: _kind,
      period: _kind == StudyKind.vwap || _kind == StudyKind.macd
          ? defaultSpec.period
          : _period,
      deviations: defaultSpec.deviations,
      fast: defaultSpec.fast,
      slow: defaultSpec.slow,
      signal: defaultSpec.signal,
    );
    final canAdd = StudiesController.canAdd(studies, selected);
    final warning = studies.length >= StudiesController.maxStudies
        ? s.limit
        : StudyCatalog.isLowerPane(_kind) &&
              studies
                      .where((study) => StudyCatalog.isLowerPane(study.kind))
                      .length >=
                  StudiesController.maxLowerPanes
        ? s.paneLimit
        : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SpPicker<StudyKind>(
              title: s.title,
              values: StudyKind.values,
              label: (kind) => s.name(kind.name),
              selected: _kind,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
            if (_kind != StudyKind.vwap && _kind != StudyKind.macd) ...[
              Text(s.periodValue(_period)),
              Slider(
                value: _period.toDouble(),
                min: 2,
                max: 200,
                divisions: 198,
                label: '$_period',
                onChanged: (value) => setState(() => _period = value.round()),
              ),
            ],
            if (warning case final message?) ...[
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !canAdd
                  ? null
                  : () {
                      final added = ref
                          .read(
                            studiesControllerProvider(widget.instrumentId)
                                .notifier,
                          )
                          .add(selected);
                      if (added) Navigator.of(context).pop();
                    },
              child: Text(s.add),
            ),
          ],
        ),
      ),
    );
  }
}

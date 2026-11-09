import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/common_strings.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// `● Open` / `● Pre-open` / `○ Closed`, plus the
/// `Demo clock 10:00` pill while the virtual clock is on. The dot is never
/// green; the text always names the phase.
class MarketStatusPill extends ConsumerWidget {
  const MarketStatusPill({super.key, this.onDemoClockTap});

  /// Opens the debug clock sheet ; null = not tappable.
  final VoidCallback? onDemoClockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      marketClockProvider.select(
        (c) => (c.value ?? MarketClockState.fallback).phase,
      ),
    );
    final demo = ref.watch(demoClockTextProvider);
    final pill = _PhasePill(phase: phase);
    if (demo == null) return pill;
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final chip = _DemoClockChip(
      time: demo,
      phase: phase,
      onTap: onDemoClockTap,
    );
    final children = [
      pill,
      const SizedBox(width: SpSpace.s2, height: SpSpace.s1),
      chip,
    ];
    return stack
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          )
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

String phaseLabel(CommonStrings strings, MarketPhase p) => switch (p) {
  MarketPhase.preOpen => strings.phasePreOpen,
  MarketPhase.open => strings.phaseOpen,
  MarketPhase.closed => strings.phaseClosed,
};

/// Virtual market time as `HH:mm` IST while the demo clock is on, else null.
/// Recomputed on the freshness tick; listeners only see minute changes.
final demoClockTextProvider = Provider.autoDispose<String?>((ref) {
  final clock = ref.watch(marketClockProvider).value;
  if (clock == null || !clock.overridden) return null;
  ref.watch(freshnessTickProvider);
  final market = clock.marketNow(ref.watch(serverClockProvider).now());
  final ist = market.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(ist.hour)}:${two(ist.minute)}';
});

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase});
  final MarketPhase phase;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final strings = context.strings.common;
    final label = phaseLabel(strings, phase);
    final dot = switch (phase) {
      MarketPhase.open => BoxDecoration(
        color: sp.accent,
        shape: BoxShape.circle,
      ),
      MarketPhase.preOpen => BoxDecoration(
        color: sp.warn,
        shape: BoxShape.circle,
      ),
      MarketPhase.closed => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: sp.textTertiary, width: 1.5),
      ),
    };
    return Semantics(
      label: strings.marketSemantics(label),
      child: ExcludeSemantics(
        child: _Pill(
          background: sp.surface2,
          children: [
            DecoratedBox(
              decoration: dot,
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: SpSpace.s1),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: sp.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoClockChip extends StatelessWidget {
  const _DemoClockChip({required this.time, required this.phase, this.onTap});
  final String time;
  final MarketPhase phase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final strings = context.strings.common;
    final style = context.spText.change.copyWith(color: sp.info);
    return Semantics(
      button: onTap != null,
      label: strings.demoClockSemantics(time, phaseLabel(strings, phase)),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SpRadius.pill),
          child: _Pill(
            background: sp.infoTint,
            children: [
              Icon(AppIcons.time, size: 14, color: sp.info),
              const SizedBox(width: SpSpace.s1),
              Text(strings.demoClock(time), style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.background, required this.children});
  final Color background;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: SpSpace.s2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(SpRadius.pill),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

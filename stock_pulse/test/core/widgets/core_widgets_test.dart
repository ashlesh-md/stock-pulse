import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/widgets/change_chip.dart';
import 'package:stock_pulse/core/widgets/connection_badge.dart';
import 'package:stock_pulse/core/widgets/global_stale_banner.dart';
import 'package:stock_pulse/core/widgets/market_status_pill.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';

import '../../helpers/fake_market_socket.dart';
import '../../helpers/sp_app.dart';

void main() {
  group('ChangeChip (FR-2: never colour-only)', () {
    testWidgets('up, down and flat carry a glyph and sign', (tester) async {
      Future<(String, Color?)> show(double c, double p) async {
        await tester.pumpWidget(spApp(ChangeChip(change: c, changePct: p)));
        final t = tester.widget<Text>(find.byType(Text));
        return (t.data!, t.style?.color);
      }

      expect(await show(12.4, 0.51), ('▲ +12.40 (+0.51%)', SpColors.dark.up));
      expect(await show(-3, -0.2), ('▼ -3.00 (-0.20%)', SpColors.dark.down));
      expect(await show(0, 0), ('– 0.00 (0.00%)', SpColors.dark.textSecondary));
      expect(find.bySemanticsLabel('Unchanged'), findsOneWidget);
    });
  });

  group('ConnectionBadge (FR-83)', () {
    testWidgets('Live → Reconnecting → Offline, warn not red', (tester) async {
      final status = StreamController<NetworkStatus>();
      addTearDown(status.close);
      await tester.pumpWidget(
        spApp(
          const ConnectionBadge(),
          overrides: [
            networkStatusProvider.overrideWith((ref) => status.stream),
          ],
        ),
      );
      for (final (s, label) in [
        (NetworkStatus.live, 'Live'),
        (NetworkStatus.reconnecting, 'Reconnecting'),
        (NetworkStatus.offline, 'Offline'),
      ]) {
        status.add(s);
        await tester.pump();
        await tester.pump(); // Riverpod 3 notifies on the next frame
        final text = tester.widget<Text>(find.text(label));
        expect(find.bySemanticsLabel('Connection $label'), findsOneWidget);
        expect(
          text.style?.color,
          s == NetworkStatus.live
              ? SpColors.dark.textSecondary
              : SpColors.dark.warn,
        );
        expect(text.style?.color, isNot(SpColors.dark.down));
      }
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });

  group('MarketStatusPill (FR-14)', () {
    Widget pill(MarketClockState s) => spApp(
      const MarketStatusPill(),
      overrides: [
        marketClockProvider.overrideWith((ref) => Stream.value(s)),
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 11, 9, 3, 40)),
        ),
      ],
    );

    testWidgets('clock 09:10 → Pre-open', (tester) async {
      await tester.pumpWidget(
        pill(MarketClockState.fallback.copyWith(phase: MarketPhase.preOpen)),
      );
      await tester.pump();
      expect(find.text('Pre-open'), findsOneWidget);
      expect(find.textContaining('Demo clock'), findsNothing);
    });

    testWidgets('demo clock shows virtual IST time next to the phase', (
      tester,
    ) async {
      // Server 03:40 UTC = 09:10 IST; offset +50 min → 10:00 IST.
      await tester.pumpWidget(
        pill(
          MarketClockState.fallback.copyWith(
            overridden: true,
            marketOffsetMs: 50 * 60 * 1000,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Demo clock 10:00'), findsOneWidget);
    });
  });

  group('StaleBadge', () {
    testWidgets('shows the fixed as-of time', (tester) async {
      final at = DateTime(2026, 11, 9, 10, 42, 7);
      await tester.pumpWidget(spApp(StaleBadge(asOf: at)));
      expect(find.text('Stale since ${Fmt.time(at)}'), findsOneWidget);
    });
  });

  group('GlobalStaleBanner (FR-90)', () {
    late FakeClock clock;
    late FakeMarketSocket socket;
    final t0 = DateTime(2026, 11, 9, 10, 42, 7);

    Widget app({MarketPhase phase = MarketPhase.open}) => ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock),
        marketSocketProvider.overrideWithValue(socket),
        marketClockProvider.overrideWith(
          (ref) =>
              Stream.value(MarketClockState.fallback.copyWith(phase: phase)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => GlobalStaleBanner(child: child!),
        home: const _Counter(),
      ),
    );

    setUp(() {
      clock = FakeClock(t0);
      socket = FakeMarketSocket(status: const SocketConnected(sessionId: 's'));
      socket.emit({'type': 'ticks'}, at: t0);
    });

    testWidgets(
      'no frame for 5.1 s while Open → banner; first frame hides it',
      (tester) async {
        await tester.pumpWidget(app());
        await tester.tap(find.byType(_Counter));
        await tester.pump();

        clock.advance(const Duration(milliseconds: 5000));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.textContaining('Prices not live'),
          findsNothing,
          reason: 'exactly 5.0 s is live',
        );

        clock.advance(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(
          find.text('Prices not live since ${Fmt.time(t0)}'),
          findsOneWidget,
        );
        expect(
          find.text('taps 1'),
          findsOneWidget,
          reason: 'app keeps its state',
        );

        socket.emit({'type': 'ticks'}, at: clock.now());
        clock.advance(const Duration(milliseconds: 10)); // ticks carry new time
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(find.textContaining('Prices not live'), findsNothing);
        expect(find.text('taps 1'), findsOneWidget);
      },
    );

    testWidgets('Closed and live: no banner without frames', (tester) async {
      await tester.pumpWidget(app(phase: MarketPhase.closed));
      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('Prices not live'), findsNothing);
    });

    testWidgets('socket not live > 5 s → banner even when Closed', (
      tester,
    ) async {
      await tester.pumpWidget(app(phase: MarketPhase.closed));
      await tester.pump(); // network status stream subscribed
      socket.setStatus(
        const SocketReconnecting(
          attempt: 1,
          delay: Duration(seconds: 1),
          reason: 'x',
        ),
      );
      await tester.pump();
      clock.advance(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
        find.text('Prices not live since ${Fmt.time(t0)}'),
        findsOneWidget,
      );
    });
  });

  group('showSpSheet', () {
    testWidgets('counts itself in openSheetCountProvider while open', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        spApp(Builder(builder: (c) => Text('host', key: Key('${ctx = c}')))),
      );
      final container = ProviderScope.containerOf(ctx);
      unawaited(
        showSpSheet<void>(
          ctx,
          maxWidth: 480,
          builder: (_) => const Text('sheet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
      expect(container.read(openSheetCountProvider), 1);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
      expect(container.read(openSheetCountProvider), 0);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: GestureDetector(
      onTap: () => setState(() => taps++),
      child: Center(child: Text('taps $taps')),
    ),
  );
}

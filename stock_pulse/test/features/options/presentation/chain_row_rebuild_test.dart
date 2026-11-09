import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_list.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_row_tile.dart';
import 'package:stock_pulse/features/options/presentation/widgets/option_side_cell.dart';

import '../../../helpers/build_counter.dart';

class _Repository extends Mock implements ChainRepository {}

class _FakeChainRequest extends Fake implements ChainRequest {}

class _Feed implements ChainFeed {
  final controller = StreamController<ChainView>.broadcast(sync: true);
  final ranges = <(int, int)>[];

  void dispose() => unawaited(controller.close());

  @override
  Stream<ChainView> get views => controller.stream;

  @override
  void setVisibleRange(int fromStrike, int toStrike) =>
      ranges.add((fromStrike, toStrike));
}

const _atm = 24500;
final _strikes = [for (var i = -20; i <= 20; i++) _atm + i * 50];

OptionCell _cell(String id, {double ltp = 100, int oi = 500}) =>
    OptionCell(contractId: id, ltp: ltp, change: 0, oi: oi, oiChange: 0);

ChainView _view({double spot = 24512, int atm = _atm, int seq = 1}) =>
    ChainView(
      chainId: 'NIFTY:2026-11-09',
      seq: seq,
      asOf: DateTime.utc(2026, 11, 8, 12, 0, seq),
      spot: spot,
      atm: atm,
      status: ChainStatus.open,
      strikes: _strikes,
      rows: {
        for (final strike in _strikes)
          strike: ChainRow(
            strike: strike,
            ce: _cell('NIFTY${strike}CE', oi: strike == _atm ? 1000 : 500),
            pe: _cell('NIFTY${strike}PE', oi: 800),
          ),
      },
    );

void main() {
  late _Repository repository;
  late _Feed feed;
  late ChainView current;

  setUp(() {
    repository = _Repository();
    feed = _Feed();
    current = _view();
    addTearDown(feed.dispose);
    when(() => repository.expiries('NIFTY')).thenAnswer(
      (_) async => Success([
        Expiry(
          code: '2026-11-09',
          expiryAt: DateTime.utc(2026, 11, 9, 10),
          kind: ExpiryKind.weekly,
          isToday: true,
        ),
        Expiry(
          code: '2026-11-16',
          expiryAt: DateTime.utc(2026, 11, 16, 10),
          kind: ExpiryKind.weekly,
          isToday: false,
        ),
      ]),
    );
    when(() => repository.getChain('NIFTY', '2026-11-09'))
        .thenAnswer((_) async => Success(current));
    when(() => repository.getChain('NIFTY', '2026-11-16'))
        .thenAnswer((_) async => Success(current));
    when(() => repository.watchChain(any())).thenReturn(feed);
  });

  setUpAll(() => registerFallbackValue(_FakeChainRequest()));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          chainRepositoryProvider.overrideWithValue(repository),
          screenVisibleProvider(ScreenId.options).overrideWithValue(true),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ChainScreen(underlying: 'NIFTY'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S-27 TR-8 ka view rebuilds no chain cells or rows', (
    tester,
  ) async {
    await pump(tester);
    final counter = BuildCounter.attach();
    addTearDown(counter.detach);
    counter.reset();

    final next = current.copyWith(
      seq: 2,
      asOf: current.asOf.add(const Duration(seconds: 1)),
    );
    feed.controller.add(next);
    await tester.pumpAndSettle();

    expect(counter.ofType<OptionSideCell>(), 0);
    expect(counter.ofType<ChainRowTile>(), 0);
  });

  testWidgets('S-27 TR-22 opens with ATM at 55 percent of the viewport', (
    tester,
  ) async {
    await pump(tester);
    final viewport = tester.getRect(find.byType(ChainList));
    final atm = tester.getCenter(find.byKey(const ValueKey('strike:24500'))).dy;
    expect(atm - viewport.top, closeTo(viewport.height * .55, .1));
  });

  testWidgets('S-27 TR-22 expiry change recentres ATM at 55 percent', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          chainRepositoryProvider.overrideWithValue(repository),
          screenVisibleProvider(ScreenId.options).overrideWithValue(true),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ChainScreen(underlying: 'NIFTY', expiry: '2026-11-16'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(ChainList));
    final atm = tester.getCenter(find.byKey(const ValueKey('strike:24500'))).dy;
    expect(atm - viewport.top, closeTo(viewport.height * .55, .1));
  });

  testWidgets('S-27 TR-8 one changed contract rebuilds only that cell', (
    tester,
  ) async {
    await pump(tester);
    final counter = BuildCounter.attach();
    addTearDown(counter.detach);
    counter.reset();

    final rows = Map<int, ChainRow>.of(current.rows);
    final row = rows[_atm]!;
    rows[_atm] = row.copyWith(ce: row.ce!.copyWith(ltp: 101));
    feed.controller.add(current.copyWith(seq: 2, rows: rows));
    await tester.pumpAndSettle();

    expect(counter.ofType<OptionSideCell>(), 1);
    expect(counter.ofType<ChainRowTile>(), 0);
  });

  testWidgets(
    'S-27 TR-8 spot and ATM update keep rows and scroll offset stable',
    (tester) async {
      await pump(tester);
      final list = tester.widget<ListView>(find.byType(ListView).last);
      final scroll = list.controller!;
      final offset = scroll.offset;
      final counter = BuildCounter.attach();
      addTearDown(counter.detach);
      counter.reset();

      feed.controller.add(current.copyWith(seq: 2, spot: 24662, atm: 24650));
      await tester.pumpAndSettle();

      expect(scroll.offset, offset);
      expect(counter.ofType<ChainRowTile>(), 0);
      expect(counter.ofKey(const ValueKey('strike:24500')), 1);
      expect(counter.ofKey(const ValueKey('strike:24650')), 1);
      expect(find.text('ATM'), findsOneWidget);
    },
  );

  testWidgets('Back to ATM hides when a moving ATM enters the viewport', (
    tester,
  ) async {
    await pump(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -1100));
    await tester.pumpAndSettle();
    expect(find.text('Back to ATM'), findsOneWidget);

    feed.controller.add(current.copyWith(seq: 2, atm: _strikes[35]));
    await tester.pumpAndSettle();

    expect(find.text('ATM'), findsOneWidget);
    expect(find.text('Back to ATM'), findsNothing);
  });
}

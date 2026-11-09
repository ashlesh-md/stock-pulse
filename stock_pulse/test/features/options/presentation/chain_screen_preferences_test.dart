import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/presentation/feedback_host.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';

import '../../../helpers/fake_local_prefs.dart';

class _Repository extends Mock implements ChainRepository {}

ChainView _emptyView(
  String underlying, {
  ChainStatus status = ChainStatus.open,
}) => ChainView(
  chainId: '$underlying:2026-11-09',
  seq: 1,
  asOf: DateTime.utc(2026, 11, 8),
  spot: 100,
  atm: 100,
  status: status,
  strikes: const [],
  rows: const {},
);

void main() {
  late _Repository repository;
  late FakeLocalPrefs prefs;

  setUp(() {
    repository = _Repository();
    prefs = FakeLocalPrefs(
      LocalPrefsData.defaults.copyWith(lastChainUnderlying: 'RELIANCE'),
    );
    for (final underlying in ['NIFTY', 'RELIANCE']) {
      when(() => repository.expiries(underlying)).thenAnswer(
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
      when(() => repository.getChain(underlying, '2026-11-09'))
          .thenAnswer((_) async => Success(_emptyView(underlying)));
      when(() => repository.getChain(underlying, '2026-11-16'))
          .thenAnswer((_) async => Success(_emptyView(underlying)));
    }
  });

  Future<void> pump(WidgetTester tester, {String? underlying}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(repository),
          localPrefsProvider.overrideWith((ref) async => prefs),
          screenVisibleProvider(ScreenId.options).overrideWithValue(false),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ChainScreen(underlying: underlying),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('options tab restores the last viewed underlying', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('RELIANCE options'), findsOneWidget);
    verify(() => repository.expiries('RELIANCE')).called(1);
  });

  testWidgets('opening an explicit underlying remembers it', (tester) async {
    await pump(tester, underlying: 'NIFTY');
    await tester.pump();
    expect(prefs.data.lastChainUnderlying, 'NIFTY');
  });

  testWidgets('an expired chain opens the next expiry and announces the roll', (
    tester,
  ) async {
    when(() => repository.getChain('NIFTY', '2026-11-09')).thenAnswer(
      (_) async => Success(_emptyView('NIFTY', status: ChainStatus.expired)),
    );
    final router = GoRouter(
      initialLocation: '/options?u=NIFTY&e=2026-11-09',
      routes: [
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, state) {
            final route = OptionChainRoute.fromState(state);
            return ChainScreen(
              underlying: route.underlying,
              expiry: route.expiry,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(repository),
          localPrefsProvider.overrideWith((ref) async => prefs),
          screenVisibleProvider(ScreenId.options).overrideWithValue(false),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
          builder: (_, child) => FeedbackHost(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('16 Nov  Weekly', findRichText: true), findsOneWidget);
    expect(
      find.text('2026-11-09 expired · showing 2026-11-16'),
      findsOneWidget,
    );
    verify(() => repository.getChain('NIFTY', '2026-11-16')).called(1);
  });
}

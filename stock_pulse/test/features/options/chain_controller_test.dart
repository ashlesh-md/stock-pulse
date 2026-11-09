import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

class Repo extends Mock implements ChainRepository {}

class Feed extends Mock implements ChainFeed {}

class _Visible extends Notifier<bool> {
  @override
  bool build() => true;
  void set({required bool value}) => state = value;
}

void main() {
  setUpAll(
    () => registerFallbackValue(
      const ChainRequest(
        underlying: 'NIFTY',
        expiry: 'x',
        fromStrike: 1,
        toStrike: 2,
      ),
    ),
  );
  test('no expiries is a finished empty state', () async {
    final repo = Repo();
    when(() => repo.expiries('NIFTY'))
        .thenAnswer((_) async => const Success([]));
    final c = ProviderContainer(
      overrides: [chainRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final provider = chainControllerProvider((
      underlying: 'NIFTY',
      expiry: null,
    ));
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final result = await c.read(provider.future);
    expect(result.view, isNull);
    expect(result.expiries, isEmpty);
  });
  test('loads a snapshot, merges live views and releases feed', () async {
    final repo = Repo();
    final feed = Feed();
    var cancelled = false;
    final updates = StreamController<ChainView>(
      onCancel: () => cancelled = true,
    );
    addTearDown(updates.close);
    final view = ChainView(
      chainId: 'NIFTY:x',
      seq: 1,
      asOf: DateTime.utc(2026),
      spot: 100,
      atm: 100,
      status: ChainStatus.open,
      strikes: const [100],
      rows: const {},
    );
    when(() => repo.expiries('NIFTY')).thenAnswer(
      (_) async => Success([
        Expiry(
          code: 'x',
          expiryAt: DateTime.utc(2026),
          kind: ExpiryKind.weekly,
          isToday: false,
        ),
      ]),
    );
    when(() => repo.getChain('NIFTY', 'x'))
        .thenAnswer((_) async => Success(view));
    when(() => repo.watchChain(any())).thenReturn(feed);
    when(() => feed.views).thenAnswer((_) => updates.stream);
    final c = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(repo),
        screenVisibleProvider(ScreenId.options).overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    final provider = chainControllerProvider((
      underlying: 'NIFTY',
      expiry: null,
    ));
    final sub = c.listen(provider, (_, _) {});
    expect((await c.read(provider.future)).expiry, 'x');
    updates.add(view.copyWith(seq: 2, spot: 101));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(provider).requireValue.view?.spot, 101);
    c.read(provider.notifier).setVisibleRange(50, 150);
    verify(() => feed.setVisibleRange(50, 150)).called(1);
    sub.close();
    await c.pump();
    expect(cancelled, isTrue);
  });
  test('repository failure becomes an error', () async {
    final repo = Repo();
    when(() => repo.expiries('NIFTY'))
        .thenAnswer((_) async => const Failure(NetworkError()));
    final c = ProviderContainer(
      overrides: [chainRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final provider = chainControllerProvider((
      underlying: 'NIFTY',
      expiry: null,
    ));
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(provider.future), throwsA(isA<NetworkError>()));
  });

  test(
    'U-3: hiding the tab pauses the feed without reloading the chain',
    () async {
      final repo = Repo();
      final feed = Feed();
      var listens = 0;
      var cancels = 0;
      final updates = StreamController<ChainView>.broadcast(
        onListen: () => listens++,
        onCancel: () => cancels++,
      );
      addTearDown(updates.close);
      final view = ChainView(
        chainId: 'NIFTY:x',
        seq: 1,
        asOf: DateTime.utc(2026),
        spot: 100,
        atm: 100,
        status: ChainStatus.open,
        strikes: const [100],
        rows: const {},
      );
      when(() => repo.expiries('NIFTY')).thenAnswer(
        (_) async => Success([
          Expiry(
            code: 'x',
            expiryAt: DateTime.utc(2026),
            kind: ExpiryKind.weekly,
            isToday: false,
          ),
        ]),
      );
      when(() => repo.getChain('NIFTY', 'x'))
          .thenAnswer((_) async => Success(view));
      when(() => repo.watchChain(any())).thenReturn(feed);
      when(() => feed.views).thenAnswer((_) => updates.stream);
      final visible = NotifierProvider<_Visible, bool>(_Visible.new);
      final c = ProviderContainer(
        overrides: [
          chainRepositoryProvider.overrideWithValue(repo),
          screenVisibleProvider(ScreenId.options)
              .overrideWith((ref) => ref.watch(visible)),
        ],
      );
      addTearDown(c.dispose);
      final provider = chainControllerProvider((
        underlying: 'NIFTY',
        expiry: null,
      ));
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await c.read(provider.future);
      expect(listens, 1);

      c.read(visible.notifier).set(value: false);
      await c.pump();
      expect(cancels, 1);
      c.read(visible.notifier).set(value: true);
      await c.pump();
      expect(listens, 2);
      expect(c.read(provider).hasValue, isTrue);
      verify(() => repo.getChain('NIFTY', 'x')).called(1);
    },
  );
}

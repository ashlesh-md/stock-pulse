import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/application/chain_state.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

/// Loads one chain over REST, then streams it while the Options tab is
/// visible. Hiding the tab only pauses the feed; it never reloads.
class ChainController extends AsyncNotifier<ChainState> {
  ChainController(this.target);
  final ({String underlying, String? expiry}) target;
  ChainRequest? _request;
  ChainFeed? _feed;
  StreamSubscription<ChainView>? _sub;

  @override
  Future<ChainState> build() async {
    final repo = ref.watch(chainRepositoryProvider);
    final visibility = screenVisibleProvider(ScreenId.options);
    ref
      ..listen(visibility, (_, visible) => visible ? _start(repo) : _stop())
      ..onDispose(_stop);
    final expiries = (await repo.expiries(target.underlying)).getOrThrow();
    if (expiries.isEmpty) {
      return const ChainState(expiries: [], expiry: '', view: null);
    }
    final code =
        expiries.where((e) => e.code == target.expiry).firstOrNull?.code ??
        expiries.first.code;
    final view = (await repo.getChain(target.underlying, code)).getOrThrow();
    final strikes = view.strikes;
    if (strikes.isNotEmpty) {
      _request = ChainRequest(
        underlying: target.underlying,
        expiry: code,
        fromStrike: strikes.first,
        toStrike: strikes.last,
      );
      if (ref.mounted && ref.read(visibility)) _start(repo);
    }
    return ChainState(
      expiries: List.unmodifiable(expiries),
      expiry: code,
      view: view,
    );
  }

  void _start(ChainRepository repo) {
    final request = _request;
    if (_sub != null || request == null) return;
    final feed = _feed = repo.watchChain(request);
    _sub = feed.views.listen((view) {
      final current = state.value;
      if (current != null) state = AsyncData(current.copyWith(view: view));
    });
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    _feed = null;
  }

  /// Narrows the live range to the strikes on screen.
  void setVisibleRange(int from, int to) => _feed?.setVisibleRange(from, to);
  void retry() => ref.invalidateSelf();
}

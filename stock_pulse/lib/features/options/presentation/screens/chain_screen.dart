import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/widgets/empty_view.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/core/widgets/sp_tab_app_bar.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_body.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_target.dart';

const _optionUnderlyings = ['NIFTY', 'RELIANCE', 'HDFCBANK'];

/// Options tab. It selects the expiries and the strike list only; each row
/// selects its own cells, so a chain frame never rebuilds the header.
class ChainScreen extends ConsumerStatefulWidget {
  const ChainScreen({super.key, this.underlying, this.expiry});
  final String? underlying;
  final String? expiry;

  @override
  ConsumerState<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends ConsumerState<ChainScreen> {
  ChainTarget? _displayTarget;
  bool _hasDisplayedChain = false;
  String? _rememberedUnderlying;
  String? _rolledFromExpiry;

  Future<void> _chooseUnderlying() async {
    final strings = context.strings.options;
    final underlying = await showSpPicker<String>(
      context,
      title: strings.chooseUnderlying,
      values: _optionUnderlyings,
      label: (value) => value,
      selected: widget.underlying ?? _displayTarget?.underlying,
    );
    if (!mounted || underlying == null) return;
    context.goTo(OptionChainRoute(underlying: underlying));
  }

  void _rememberUnderlying(String underlying) {
    if (_rememberedUnderlying == underlying) return;
    _rememberedUnderlying = underlying;
    unawaited(_persistUnderlying(underlying));
  }

  Future<void> _persistUnderlying(String underlying) async {
    try {
      final prefs = await ref.read(localPrefsProvider.future);
      if (!mounted || prefs.data.lastChainUnderlying == underlying) return;
      await prefs.update(
        (current) => current.copyWith(lastChainUnderlying: underlying),
      );
    } on Object {
      // Tests or embedders without persistent preferences still get a chain.
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.underlying == null
        ? ref.watch(localPrefsProvider)
        : null;
    if (widget.underlying == null && prefs!.isLoading && !prefs.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final underlying =
        widget.underlying ?? prefs?.value?.data.lastChainUnderlying;
    final s = context.strings.options;
    if (underlying == null) {
      return Scaffold(
        appBar: SpTabAppBar(title: Text(s.sectionTitle)),
        body: EmptyView(
          icon: AppIcons.options,
          title: s.chooseUnderlying,
          message: s.chooseUnderlyingHint,
          actionLabel: s.chooseUnderlyingAction,
          onAction: () => unawaited(_chooseUnderlying()),
        ),
      );
    }
    final target = (underlying: underlying, expiry: widget.expiry);
    final provider = chainControllerProvider(target);
    ref.listen(provider, (_, next) {
      if (next.hasValue && _displayTarget != target) {
        setState(() {
          _displayTarget = target;
          _hasDisplayedChain = true;
        });
      }
      if (!next.hasValue) return;
      _rememberUnderlying(target.underlying);
      final state = next.requireValue;
      if (state.view?.status != ChainStatus.expired ||
          _rolledFromExpiry == state.expiry) {
        return;
      }
      final index = state.expiries.indexWhere((e) => e.code == state.expiry);
      if (index < 0 || index + 1 >= state.expiries.length) return;
      final nextExpiry = state.expiries[index + 1];
      _rolledFromExpiry = state.expiry;
      ref
          .read(feedbackControllerProvider.notifier)
          .show(
            FeedbackMessage(
              key: 'options.expired.${state.expiry}',
              text: context.strings.options.expiredNotice(
                state.expiry,
                nextExpiry.code,
              ),
            ),
          );
      context.goTo(
        OptionChainRoute(
          underlying: target.underlying,
          expiry: nextExpiry.code,
        ),
      );
    });
    final (hasValue, error) = ref.watch(
      provider.select((a) => (a.hasValue, a.error)),
    );
    return Scaffold(
      appBar: SpTabAppBar(
        title: Text(s.title(underlying)),
        actions: [
          IconButton(
            tooltip: s.chooseUnderlying,
            onPressed: () => unawaited(_chooseUnderlying()),
            icon: const Icon(AppIcons.dropDown),
          ),
        ],
      ),
      body: switch ((hasValue, error)) {
        (true, _) => ChainBody(target: target),
        (false, final Object error) => ErrorView(
          error: error,
          onRetry: () => ref.read(provider.notifier).retry(),
        ),
        _
            when _hasDisplayedChain &&
                _displayTarget?.underlying == target.underlying =>
          Stack(
            children: [
              Positioned.fill(
                child: ChainBody(
                  target: _displayTarget!,
                  pendingExpiry: target.expiry,
                ),
              ),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

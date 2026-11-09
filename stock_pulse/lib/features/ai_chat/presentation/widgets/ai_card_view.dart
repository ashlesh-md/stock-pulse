import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_shell.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_table_view.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_visual_content.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/card_visibility.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_rich_text.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

class AiCardView extends ConsumerWidget {
  const AiCardView({
    super.key,
    required this.card,
    required this.onExplain,
    this.streaming = false,
  });
  final AiCard card;

  /// The card is the newest one of an answer that is still streaming.
  final bool streaming;
  final ValueChanged<String> onExplain;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CardVisibility(
    builder: (context, {required visible}) =>
        Consumer(builder: (context, ref, _) => _body(context, ref, visible)),
  );

  Widget _body(BuildContext context, WidgetRef ref, bool visible) {
    final body = card.body;
    final id = body['id'] as String?;
    final liveState =
        visible &&
            ref.watch(screenVisibleProvider(ScreenId.ai)) &&
            card.type == 'quote' &&
            id != null
        ? ref.watch(liveQuoteProvider((id: id, throttleMs: 1000)))
        : null;
    final cachedQuote = card.type != 'quote' || id == null
        ? null
        : ref.watch(latestQuoteSnapshotProvider(id));
    final streamedQuote = liveState?.value;
    final quote = switch ((streamedQuote, cachedQuote)) {
      (final live?, final cached?) when cached.asOf.isAfter(live.asOf) =>
        cached,
      (final live?, _) => live,
      (_, final cached?) => cached,
      _ => null,
    };
    final livePriceFailed = liveState?.hasError ?? false;
    final price = (quote?.ltp ?? body['ltp']) as num?;
    final changePct = (quote?.changePct ?? body['changePct']) as num?;
    final asOf = card.type == 'quote'
        ? quote?.lastTradeTime ?? card.asOf
        : null;
    final freshnessAt = quote?.asOf ?? asOf;
    // Keep the stale marker stable while its card moves in and out of the
    // viewport. CardVisibility gates network work, but shouldn't gate status UI.
    final now = asOf == null
        ? null
        : ref.watch(freshnessTickProvider).value ??
              ref.read(serverClockProvider).now();
    final stale =
        now != null && now.difference(freshnessAt!).inMilliseconds > 5000;
    return AiCardShell(
      icon: _icon,
      label: card.title.isEmpty
          ? context.strings.chat.cardType(card.type)
          : card.title,
      streaming: streaming,
      trailing: asOf == null
          ? null
          : Text(
              context.strings.chat.asOf(Fmt.time(asOf)),
              style: context.spText.caption.copyWith(
                color: context.sp.textTertiary,
              ),
            ),
      actions: [
        for (final action in card.actions)
          TextButton(
            onPressed: () => _act(context, ref, action),
            child: Text(action.label),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (card.type == 'quote' && price != null)
            Text(
              Fmt.price(price.toDouble()),
              style: context.spText.price.copyWith(fontSize: 22),
            ),
          if (card.type == 'quote' && changePct != null)
            Text(
              Fmt.percent(changePct.toDouble()),
              style: context.spText.change.copyWith(
                color: changePct < 0 ? context.sp.down : context.sp.up,
              ),
            ),
          if (livePriceFailed)
            Semantics(
              liveRegion: true,
              child: Text(
                context.strings.chat.livePriceUnavailable,
                style: context.spText.caption.copyWith(color: context.sp.warn),
              ),
            ),
          if (stale) StaleBadge(asOf: freshnessAt),
          AiVisualContent(card: card),
          if (card.type == 'table')
            AiTableView(
              body: card.body,
              onOpenRow: (id) =>
                  unawaited(context.pushTo<void>(StockRoute(id))),
            ),
          if (card.text.isNotEmpty) ChatRichText(text: card.text),
        ],
      ),
    );
  }

  IconData get _icon => switch (card.type) {
    'quote' || 'chart' => AppIcons.watchlist,
    'chain' || 'table' => AppIcons.options,
    'payoff' => AppIcons.chartArea,
    _ => AppIcons.ai,
  };

  void _act(BuildContext context, WidgetRef ref, AiAction action) {
    ref.read(analyticsProvider).log(Events.aiCardAction(action.kind));
    switch (action.kind) {
      case 'explain':
        onExplain('Explain ${action.args['term'] ?? action.label}');
      case 'open_stock' || 'open_chart':
        final id = action.args['instrumentId'] ?? action.args['id'];
        if (id is String) unawaited(context.pushTo<void>(StockRoute(id)));
      case 'open_chain':
        context.goTo(
          OptionChainRoute(
            underlying: action.args['underlying'] as String?,
            expiry: action.args['expiry'] as String?,
          ),
        );
      case 'view_payoff':
        final legs = (card.body['legs'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>();
        ref
            .read(strategyDraftControllerProvider.notifier)
            .load(
              StrategyArgs(
                legs: [
                  for (final leg in legs)
                    StrategyLeg(
                      contractId: leg['id']! as String,
                      side: leg['side'] == 'sell'
                          ? OrderSide.sell
                          : OrderSide.buy,
                      lots: _lots(leg['lots']),
                      premium: (leg['premium']! as num).toDouble(),
                    ),
                ],
              ),
            );
        unawaited(context.pushTo<void>(const StrategyRoute()));
      case 'trade':
        final id = action.args['instrumentId'] ?? action.args['id'];
        if (id is String) {
          unawaited(
            context.pushTo<void>(
              OrderTicketRoute(
                OrderTicketArgs(
                  instrumentId: id,
                  side: action.args['side'] == 'sell'
                      ? OrderSide.sell
                      : OrderSide.buy,
                  lots: _lots(action.args['lots']),
                  source: OrderSource.ai,
                ),
              ),
            ),
          );
        }
      case 'set_alert':
        final id = action.args['instrumentId'] ?? action.args['id'];
        if (id is String) unawaited(context.pushTo<void>(StockRoute(id)));
    }
  }

  /// Server JSON may send `1.0` or a string; anything but a positive int is 1.
  static int _lots(Object? value) => switch (value) {
    final int n when n > 0 => n,
    _ => 1,
  };
}

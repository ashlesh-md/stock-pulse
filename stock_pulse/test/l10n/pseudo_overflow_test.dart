import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/app_strings_pseudo.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/more_screen.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';

import 'pseudo_app.dart';

const _screens = [
  (name: 'watchlist', location: '/watchlist', type: WatchlistScreen),
  (name: 'stock page', location: '/stock/RELIANCE', type: StockDetailScreen),
  (name: 'options chain', location: '/options?u=NIFTY', type: ChainScreen),
  (
    name: 'order ticket',
    location: '/order/RELIANCE?side=buy&lots=2',
    type: OrderTicketScreen,
  ),
  (name: 'portfolio positions', location: '/portfolio', type: PortfolioScreen),
  (
    name: 'portfolio holdings',
    location: '/portfolio?tab=holdings',
    type: PortfolioScreen,
  ),
  (
    name: 'portfolio orders',
    location: '/portfolio?tab=orders',
    type: PortfolioScreen,
  ),
  (name: 'AI chat', location: '/ai', type: AiChatScreen),
  (name: 'more', location: '/more', type: MoreScreen),
];

const _sizes = [
  (name: '360 dp', textScale: 1.0),
  (name: '360 dp at 1.3x text', textScale: 1.3),
];

void main() {
  for (final size in _sizes) {
    group('FR-164 pseudo-locale at ${size.name}', () {
      for (final screen in _screens) {
        testWidgets('${screen.name} lays out without overflow', (tester) async {
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(
            details.exceptionAsString().split('\n').take(3).join(' '),
          );
          addTearDown(() => FlutterError.onError = previous);
          final app = PseudoApp(width: 360, textScale: size.textScale);

          await app.pump(tester);
          await app.go(tester, screen.location);
          FlutterError.onError = previous;

          expect(
            tester.element(find.byType(screen.type)).strings,
            isA<AppStringsPseudo>(),
          );
          expect(errors, isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}

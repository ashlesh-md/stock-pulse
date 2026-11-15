import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_history.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/domain/settlement.dart';

import '../helpers/chain_fixtures.dart';
import '../helpers/fake_market_repository.dart';

/// 10:30 IST on a Tuesday, inside market hours.
final pseudoNow = DateTime.utc(2026, 11, 10, 5);

Instrument _equity(String symbol, String name, String sector) => Instrument(
  symbol: symbol,
  name: name,
  exchange: 'NSE',
  sector: sector,
  tickSize: 0.05,
  lotSize: 1,
);

Quote _quote(String symbol, double ltp, double change) => Quote(
  symbol: symbol,
  ltp: ltp,
  change: change,
  changePercent: change / ltp * 100,
  lastTradeTime: pseudoNow,
  open: ltp - 10,
  high: ltp + 25,
  low: ltp - 30,
  prevClose: ltp - change,
  volume: 1234567,
);

/// Long names and real-looking prices, so rows carry their widest text.
FakeMarketRepository pseudoMarket() => FakeMarketRepository(
  instruments: [
    _equity('NIFTY', 'Nifty 50 Index', 'Index'),
    _equity('RELIANCE', 'Reliance Industries Limited', 'Oil Gas & Energy'),
    _equity('HDFCBANK', 'HDFC Bank Limited', 'Financial Services'),
  ],
  quotes: [
    _quote('NIFTY', 24512.35, 112.4),
    _quote('RELIANCE', 2945.6, -38.25),
    _quote('HDFCBANK', 1712.05, 4.1),
  ],
);

final _order = Order(
  id: 'ORD-000123456',
  symbol: 'RELIANCE',
  side: OrderSide.buy,
  type: OrderType.limit,
  quantity: 120,
  limitPrice: 2940.5,
  status: OrderStatus.open,
  createdAt: pseudoNow,
  updatedAt: pseudoNow,
);

const _position = Position(
  symbol: 'HDFCBANK',
  quantity: 250,
  averagePrice: 1698.45,
  realizedPnl: 12450.75,
);

const _holding = Holding(
  symbol: 'RELIANCE',
  quantity: 1500,
  averagePrice: 2810.35,
);

const _funds = Funds(available: 1234567.89, version: 1);

class _ChainFeed implements ChainFeed {
  @override
  Stream<ChainView> get views => Stream.value(fixtureChain());

  @override
  void setVisibleRange(int fromStrike, int toStrike) {}
}

class PseudoChainRepository implements ChainRepository {
  @override
  ChainFeed watchChain(ChainRequest req) => _ChainFeed();

  @override
  Future<Result<List<Expiry>>> expiries(String underlying) async => Success([
    Expiry(
      code: '2026-11-09',
      expiryAt: DateTime.utc(2026, 11, 9, 10),
      kind: ExpiryKind.weekly,
      isToday: true,
    ),
    Expiry(
      code: '2026-11-25',
      expiryAt: DateTime.utc(2026, 11, 25, 10),
      kind: ExpiryKind.monthly,
      isToday: false,
    ),
  ]);

  @override
  Future<Result<ChainView>> getChain(String underlying, String expiry) async =>
      Success(fixtureChain());
}

class PseudoPortfolioRepository implements PortfolioRepository {
  @override
  Stream<Order> get orderUpdates => const Stream.empty();

  @override
  Future<Result<List<Order>>> getOrders() async => Success([_order]);

  @override
  Future<Result<List<Position>>> getPositions() async =>
      const Success([_position]);

  @override
  PortfolioBook? get current => null;

  @override
  Stream<List<Position>> watchPositions() => Stream.value(const [_position]);

  @override
  Stream<List<Holding>> watchHoldings() => Stream.value(const [_holding]);

  @override
  Stream<Funds> watchFunds() => Stream.value(_funds);

  @override
  Stream<Settlement> get settlements => const Stream.empty();

  @override
  Future<Result<List<Holding>>> getHoldings() async =>
      const Success([_holding]);

  @override
  Future<Result<Funds>> getFunds() async => const Success(_funds);

  @override
  Future<Result<Order>> placeOrder({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required int quantity,
    double? limitPrice,
    String? idempotencyKey,
    ProductType product = ProductType.cnc,
    int? lots,
    double? triggerPrice,
  }) async => Success(_order);

  @override
  Future<Result<Order>> cancelOrder(String id) async => Success(_order);
}

class PseudoOrderRepository implements OrderRepository {
  @override
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) async => PlaceAcked(_order);

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) async =>
      Success(_order);

  @override
  Future<Result<List<Order>>> getOrders() async => Success([_order]);

  @override
  Future<Result<Order>> cancel(String id) async => Success(_order);

  @override
  Stream<Order> get updates => const Stream.empty();

  @override
  Stream<void> get resyncCompleted => const Stream.empty();
}

class PseudoPortfolioController extends PortfolioController {
  @override
  Future<PortfolioState> build() async => PortfolioState(
    orders: [_order],
    positions: const [_position],
    ltp: const {'HDFCBANK': 1712.05},
    holdings: const [_holding],
    holdingsLoaded: true,
  );
}

/// No saved answers, so the chat opens on its suggestions.
class PseudoChatHistory implements ChatHistory {
  @override
  Future<ChatPage> read({String? beforeId, required int limit}) async =>
      (answers: const <ChatAnswer>[], hasMore: false);

  @override
  Future<void> save(ChatAnswer answer) async {}

  @override
  Future<void> clear() async {}
}

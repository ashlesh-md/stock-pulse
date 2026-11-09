import 'dart:async';
import 'dart:math';

import 'package:market_server/src/account_api.dart';
import 'package:market_server/src/account_book.dart';
import 'package:market_server/src/ai/ai_api.dart';
import 'package:market_server/src/broker.dart';
import 'package:market_server/src/clock_scheduler.dart';
import 'package:market_server/src/debug_api.dart';
import 'package:market_server/src/expiry_service.dart';
import 'package:market_server/src/fault_injector.dart';
import 'package:market_server/src/instruments.dart';
import 'package:market_server/src/live_market_reads.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/option_book.dart';
import 'package:market_server/src/options_api.dart';
import 'package:market_server/src/rest_api.dart';
import 'package:market_server/src/ws_gateway.dart';
import 'package:shelf/shelf.dart';

export 'src/broker.dart';
export 'src/clock_scheduler.dart';
export 'src/instruments.dart';
export 'src/ist.dart';
export 'src/market_calendar.dart';
export 'src/market_clock.dart';
export 'src/market_engine.dart';
export 'src/market_reads.dart';
export 'src/models.dart';
export 'src/rest_api.dart' show demoToken;
export 'src/time_buckets.dart';
export 'src/ws_gateway.dart';

/// Everything the server runs, wired together. Tests build one of these with
/// a seeded engine; `bin/server.dart` builds one and serves [handler].
///
/// [clock] defaults to demo mode on the NSE [calendar]. A supplied [engine]
/// is used as is (no phases); otherwise the engine runs on
/// [clock] with phases and the [scheduler].
class MarketServer {
  MarketServer({
    MarketEngine? engine,
    MarketClock? clock,
    MarketCalendar? calendar,
    Random? random,
    bool debug = false,
    bool load = false,
    Duration restLatency = Duration.zero,
    Duration? flushInterval,
    Duration keepAliveInterval = const Duration(seconds: 1),
  }) : calendar = calendar ?? MarketCalendar.nse() {
    this.clock = clock ?? MarketClock.demo(this.calendar);
    scheduler = ClockScheduler(this.clock, this.calendar);
    this.engine =
        engine ??
        MarketEngine(
          instruments,
          random: random,
          load: load,
          marketClock: this.clock,
          calendar: this.calendar,
          scheduler: scheduler,
        );
    scheduler
      ..on(BoundaryKind.dayRoll, this.engine.rollDay)
      ..on(BoundaryKind.open, this.engine.openMarket);
    _jumps = this.clock.jumps.listen((_) => scheduler.tick());
    broker = Broker(this.engine, clock: this.clock.marketNow);
    account = AccountBook(this.engine, clock: this.clock.marketNow);
    scheduler.on(BoundaryKind.dayRoll, broker.settleDelivery);
    broker.availableFunds = () =>
        (account.funds['available']! as num).toDouble();
    expiryService = ExpiryService(this.engine, broker, account);
    scheduler
      ..on(BoundaryKind.squareOff, expiryService.squareOff)
      ..on(BoundaryKind.settle, expiryService.settle);
    options = OptionBook(
      this.engine,
      this.clock,
      this.calendar,
      random: random,
    );
    scheduler.on(BoundaryKind.dayRoll, (_) => options.openInterest.rollDay());
    gateway = WsGateway(
      this.engine,
      broker,
      clock: this.clock,
      calendar: this.calendar,
      account: account,
      options: options,
      phaseChanges: scheduler.phaseChanges,
      flushInterval: flushInterval ?? const Duration(milliseconds: 250),
      keepAliveInterval: keepAliveInterval,
    );
    aiAnswers = AnswerStream(
      builder: AnswerBuilder(LiveMarketReads(this.engine, options, this.clock)),
    );
    final router =
        buildRestApi(
            this.engine,
            broker,
            clock: this.clock,
            calendar: this.calendar,
          )
          ..get('/health', (Request _) => Response.ok('ok'))
          ..get('/ws', gateway.handler)
          ..post('/debug/drop-connections', (Request _) async {
            final count = gateway.connectionCount;
            await gateway.dropAll();
            return Response.ok('dropped $count connection(s)\n');
          })
          ..post('/debug/freeze', (Request req) {
            final seconds =
                int.tryParse(req.url.queryParameters['seconds'] ?? '') ?? 15;
            final symbol = req.url.queryParameters['symbol'];
            if (symbol == null) {
              gateway.freezeAll(Duration(seconds: seconds));
              return Response.ok('frozen for ${seconds}s\n');
            }
            if (this.engine[symbol] == null) {
              return Response.notFound('unknown symbol $symbol\n');
            }
            gateway.freezeId(symbol, Duration(seconds: seconds));
            return Response.ok('$symbol frozen for ${seconds}s\n');
          })
          ..post('/debug/skip-seq', (Request _) {
            gateway.skipSequence();
            return Response.ok('skipped one sequence number\n');
          });
    mountAccountApi(router, account, broker);
    mountOptionsApi(router, options);
    mountAiApi(router, aiAnswers, debug: debug);
    if (debug) {
      mountDebugApi(
        router,
        this.clock,
        this.calendar,
        broker,
        account,
        gateway: gateway,
        faults: faults,
        activeAiAnswers: () => aiAnswers.active,
      );
    }
    var pipeline = const Pipeline().addMiddleware(cors());
    if (debug) {
      pipeline = pipeline.addMiddleware(faultInjection(faults, this.clock));
    }
    handler = pipeline
        .addMiddleware(requireAuth())
        .addMiddleware(latency(restLatency))
        .addHandler(router.call);
  }

  final MarketCalendar calendar;
  late final MarketClock clock;
  late final ClockScheduler scheduler;
  late final MarketEngine engine;
  late final StreamSubscription<ClockJump> _jumps;
  late final Broker broker;
  late final AccountBook account;
  late final OptionBook options;
  late final ExpiryService expiryService;
  late final WsGateway gateway;

  /// Faults queued by `POST /debug/faults` (only applied with `debug`).
  final faults = FaultInjector();

  /// AI answers (dev-ai). `aiAnswers.active` feeds `/debug/subscriptions`.
  late final AnswerStream aiAnswers;
  late final Handler handler;

  void start() => engine.start();

  Future<void> close() async {
    await _jumps.cancel();
    await scheduler.close();
    await gateway.close();
    await account.close();
    await broker.dispose();
    await engine.stop();
  }
}

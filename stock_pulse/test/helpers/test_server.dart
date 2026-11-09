import 'dart:io';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:stock_pulse/core/config/app_config.dart';

/// Runs the REAL market server in the test process on a random port, so the
/// app's REST and WebSocket code is tested against the real protocol. The
/// engine is NOT started: tests call [step] to make the market trade.
class TestServer {
  TestServer._(this.server, this._http, this.clock);

  MarketServer server;
  HttpServer _http;

  /// Server time. [advance] moves it.
  final FakeMarketClock clock;

  /// 10:00 IST on a Tuesday (an expiry day), the default test start.
  static final defaultStart = DateTime.utc(2026, 11, 10, 4, 30);

  static Future<TestServer> start({
    DateTime? wallStart,
    bool debug = false,
  }) async {
    final server = _newMarketServer(debug: debug);
    final http = await io.serve(
      server.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    return TestServer._(
      server,
      http,
      FakeMarketClock(wallStart: wallStart ?? defaultStart),
    );
  }

  AppConfig get config => AppConfig(host: '127.0.0.1', port: _http.port);

  void step([int times = 1]) {
    for (var i = 0; i < times; i++) {
      server.engine.step();
    }
  }

  /// Moves server wall time (market follows).
  void advance(Duration d) => clock.advance(d);

  /// Stops and recreates the server process boundary on the same port.
  Future<void> restartServer() async {
    final port = _http.port;
    await _http.close(force: true);
    await server.gateway.dropAll();
    await server.close();
    server = _newMarketServer();
    _http = await io.serve(server.handler, InternetAddress.loopbackIPv4, port);
  }

  Future<void> close() async {
    await server.close();
    await _http.close(force: true);
  }
}

MarketServer _newMarketServer({bool debug = false}) => MarketServer(
  engine: MarketEngine(
    instruments,
    random: Random(7),
    intradayDays: 1,
    dailyDays: 400,
  ),
  flushInterval: const Duration(milliseconds: 20),
  debug: debug,
);

/// Waits until [condition] is true, polling every 10 ms.
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

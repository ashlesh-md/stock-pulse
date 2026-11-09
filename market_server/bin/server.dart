import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// dart run bin/server.dart [--port 8080] [--latency-ms 0]
///   [--clock=demo|real] [--seed N]
///
/// `--clock=demo` (default) starts market time at 10:00 IST on today's or
/// the next trading day; `--clock=real` follows IST wall time.
Future<void> main(List<String> args) async {
  // Accepts both `--name value` and `--name=value`.
  String? arg(String name) {
    for (final a in args) {
      if (a.startsWith('$name=')) return a.substring(name.length + 1);
    }
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final port = int.tryParse(arg('--port') ?? '') ?? 8080;
  final latencyMs = int.tryParse(arg('--latency-ms') ?? '') ?? 0;
  final seed = int.tryParse(arg('--seed') ?? '');
  final clockArg = arg('--clock') ?? 'demo';
  if (clockArg != 'demo' && clockArg != 'real') {
    stderr.writeln('--clock must be demo or real, got $clockArg');
    exit(64);
  }

  final calendar = MarketCalendar.nse();
  final clock = clockArg == 'real'
      ? MarketClock(mode: ClockMode.real)
      : MarketClock.demo(calendar);
  final server = MarketServer(
    clock: clock,
    calendar: calendar,
    random: seed == null ? null : Random(seed),
    restLatency: Duration(milliseconds: latencyMs),
    debug: args.contains('--debug'),
    load: args.contains('--load'),
  )..start();
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(server.handler);

  // anyIPv4 so the Android emulator (10.0.2.2) and phones on Wi-Fi can reach it.
  final http = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Market server on http://localhost:${http.port}');
  stdout.writeln(
    '  Clock ${clock.mode.name}: market ${Ist.iso(clock.marketNow())}, '
    '${calendar.phaseAt(clock.marketNow()).name}',
  );
  stdout.writeln(
    '  REST  GET  /api/v1/instruments   (Authorization: Bearer $demoToken)',
  );
  stdout.writeln(
    '  WS         ws://localhost:${http.port}/ws?token=$demoToken',
  );
  stdout.writeln(
    '  Debug POST /debug/drop-connections | /debug/freeze?seconds=15 | /debug/skip-seq',
  );

  unawaited(
    ProcessSignal.sigint.watch().first.then((_) async {
      stdout.writeln('\nShutting down…');
      await server.close();
      await http.close(force: true);
      exit(0);
    }),
  );
}

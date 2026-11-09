import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

/// Minimal terminal WebSocket client: prints every frame in and out.
///
///   dart run bin/ws_client.dart                      # TCS,INFY in ltp mode
///   dart run bin/ws_client.dart --symbols SBIN --mode full --seconds 3
Future<void> main(List<String> args) async {
  String arg(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final symbols = arg('--symbols', 'TCS,INFY').split(',');
  final mode = arg('--mode', 'ltp');
  final seconds = int.parse(arg('--seconds', '2'));
  final uri = Uri.parse(
    arg('--url', 'ws://localhost:8080/ws?token=demo-token'),
  );

  final channel = IOWebSocketChannel.connect(uri);
  await channel.ready;
  stdout.writeln('-- connected to $uri');

  void send(Map<String, Object?> msg) {
    final text = jsonEncode(msg);
    stdout.writeln('→ $text');
    channel.sink.add(text);
  }

  channel.stream.listen(
    (frame) => stdout.writeln('← $frame'),
    onDone: () => stdout.writeln(
      '-- closed: ${channel.closeCode} ${channel.closeReason ?? ''}',
    ),
  );

  send({'op': 'subscribe', 'id': 1, 'symbols': symbols, 'mode': mode});
  send({'op': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
  await Future<void>.delayed(Duration(seconds: seconds));
  await channel.sink.close(1000, 'bye');
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

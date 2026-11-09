import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/l10n/app_strings_delegate.dart';
import 'package:stock_pulse/core/l10n/locales/en/more_strings_en.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/more/presentation/screens/socket_lab_screen.dart';
import 'package:stock_pulse/features/more/presentation/widgets/socket_status_text.dart';

class _FrameSocket extends Fake implements MarketSocket {
  final controller = StreamController<SocketFrame>.broadcast(sync: true);

  @override
  Stream<SocketFrame> get frames => controller.stream;

  Future<void> closeFrames() => controller.close();
}

void main() {
  const s = MoreStringsEn();
  late _FrameSocket socket;
  final status = StreamController<SocketStatus>.broadcast();
  tearDownAll(status.close);
  late ProviderContainer container;

  Widget app() {
    container = ProviderContainer.test(
      overrides: [
        marketSocketProvider.overrideWithValue(socket),
        socketStatusProvider.overrideWith((ref) => status.stream),
        apiClientProvider.overrideWithValue(
          ApiClient(
            const AppConfig(host: 'localhost'),
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppStringsDelegate(),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: const SocketLabScreen(),
      ),
    );
  }

  setUp(() {
    socket = _FrameSocket();
  });
  tearDown(() async {
    await socket.closeFrames();
  });

  testWidgets('FR-110: frames list newest first with their direction', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    socket.controller
      ..add(
        SocketFrame(
          outgoing: true,
          text: '{"op":"sub"}',
          at: DateTime.utc(2026),
        ),
      )
      ..add(
        SocketFrame(outgoing: false, text: '{"t":"q"}', at: DateTime.utc(2026)),
      );
    await tester.pump();

    expect(find.text('{"t":"q"}'), findsOneWidget);
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('↓'), findsOneWidget);
    expect(find.text(s.traffic(1, '9', 1)), findsOneWidget);
  });

  testWidgets('a chaos tap goes through the feedback controller', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text(s.skipSeq));
    await tester.pumpAndSettle();

    expect(
      container.read(feedbackControllerProvider)?.text,
      s.skipSeqExplained,
    );
  });

  testWidgets('the live status line follows the socket', (tester) async {
    await tester.pumpWidget(app());
    status.add(const SocketPaused());
    await tester.pump();

    expect(find.text(s.paused), findsOneWidget);
  });

  testWidgets('pause and clear change the log controls', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byTooltip(s.pauseLog));
    await tester.pump();
    expect(find.byTooltip(s.resumeLog), findsOneWidget);

    await tester.tap(find.byTooltip(s.clearLog));
    await tester.pump();
    expect(find.byTooltip(s.resumeLog), findsOneWidget);
  });

  test('each socket state is described', () {
    expect(describeSocket(s, null, '—'), s.starting);
    expect(describeSocket(s, const SocketConnecting(2), '—'), s.connecting(2));
    expect(describeSocket(s, const SocketPaused(), '—'), s.paused);
    expect(
      describeSocket(s, const SocketConnected(sessionId: 'S1'), '—'),
      s.connected('S1', '—'),
    );
    expect(
      describeSocket(
        s,
        const SocketConnected(
          sessionId: 'S1',
          latency: Duration(milliseconds: 12),
        ),
        '—',
      ),
      s.connected('S1', '12 ms'),
    );
    expect(
      describeSocket(
        s,
        const SocketReconnecting(
          attempt: 3,
          delay: Duration(milliseconds: 800),
          reason: 'closed',
        ),
        '—',
      ),
      s.reconnecting('closed', 3, 800),
    );
  });
}

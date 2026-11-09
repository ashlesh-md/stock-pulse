import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/api_client_lines.dart';

void main() {
  test('postLines reports an unreachable server as a NetworkError', () async {
    final api = ApiClient(const AppConfig(host: '127.0.0.1', port: 1));
    addTearDown(api.close);
    await expectLater(
      api.postLines('/api/v1/ai/ask', const {'question': 'nifty'}),
      emitsError(isA<NetworkError>()),
    );
  });
}

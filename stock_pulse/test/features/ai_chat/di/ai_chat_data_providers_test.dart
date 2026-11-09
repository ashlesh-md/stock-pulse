import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/ai_chat/data/ai_api.dart';
import 'package:stock_pulse/features/ai_chat/data/attachment_picker.dart';
import 'package:stock_pulse/features/ai_chat/data/live_ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/data/local_chat_history.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_data_providers.dart';

void main() {
  test(
    'data providers build the live repository, device history and picker',
    () {
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(host: '127.0.0.1', port: 1),
          ),
        ],
      );
      expect(container.read(aiRepositoryProvider), isA<LiveAiRepository>());
      expect(container.read(chatHistoryProvider), isA<LocalChatHistory>());
      expect(container.read(attachmentPickerProvider), same(pickChatFile));
    },
  );

  test('the ask endpoint posts the body to the AI path', () {
    final endpoint = aiAskEndpoint({'question': 'Q'});
    expect(endpoint.path, '/api/v1/ai/ask');
    expect(endpoint.body, {'question': 'Q'});
  });
}

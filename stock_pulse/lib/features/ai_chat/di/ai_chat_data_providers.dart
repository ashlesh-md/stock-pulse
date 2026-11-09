import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/data/api_client_lines.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/ai_chat/data/attachment_picker.dart';
import 'package:stock_pulse/features/ai_chat/data/live_ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/data/local_chat_history.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_history.dart';

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => LiveAiRepository(postLines: ref.watch(apiClientProvider).postLines),
);

final chatHistoryProvider = Provider<ChatHistory>((ref) => LocalChatHistory());
final attachmentPickerProvider = Provider<Future<PickedFile?> Function()>(
  (ref) => pickChatFile,
);

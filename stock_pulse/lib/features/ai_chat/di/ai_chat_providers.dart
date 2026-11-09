import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_controller.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_state.dart';

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

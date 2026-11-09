import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

/// One page of history, oldest first. `hasMore` is true when older answers
/// remain on the device.
typedef ChatPage = ({List<ChatAnswer> answers, bool hasMore});

abstract interface class ChatHistory {
  /// Up to [limit] answers older than [beforeId] (the newest when null).
  Future<ChatPage> read({String? beforeId, required int limit});

  /// Inserts the answer, or replaces the stored one with the same id.
  Future<void> save(ChatAnswer answer);
  Future<void> clear();
}

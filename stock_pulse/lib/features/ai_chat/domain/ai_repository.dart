import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';

abstract interface class AiRepository {
  /// One answer as events. A transport or server failure arrives as a final
  /// [AnswerFailed], never as a stream error. Cancelling the subscription
  /// aborts the request.
  Stream<AiEvent> ask(String question, {AskTopic? topic});
}

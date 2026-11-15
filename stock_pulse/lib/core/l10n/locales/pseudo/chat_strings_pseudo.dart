import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/chat_strings.dart';

final class ChatStringsPseudo extends ChatStrings {
  const ChatStringsPseudo();

  // Suggestions are sent as the question, and the simulated assistant only
  // understands English, so they keep the English text.

  @override
  String get title => pseudo(super.title);
  @override
  String get subtitle => pseudo(super.subtitle);
  @override
  String get disclaimer => pseudo(super.disclaimer);
  @override
  String get emptyTitle => pseudo(super.emptyTitle);
  @override
  String get emptyMessage => pseudo(super.emptyMessage);
  @override
  String get tryAsking => pseudo(super.tryAsking);
  @override
  String get hint => pseudo(super.hint);
  @override
  String get send => pseudo(super.send);
  @override
  String get stop => pseudo(super.stop);
  @override
  String counter(int length, int max) => pseudo(super.counter(length, max));
  @override
  String get attach => pseudo(super.attach);
  @override
  String attachLimitReached(int max) => pseudo(super.attachLimitReached(max));
  @override
  String attachmentLimit(int megabytes) =>
      pseudo(super.attachmentLimit(megabytes));
  @override
  String get attachmentError => pseudo(super.attachmentError);
  @override
  String get attachmentNote => pseudo(super.attachmentNote);
  @override
  String get removeAttachment => pseudo(super.removeAttachment);
  @override
  String get previewUnavailable => pseudo(super.previewUnavailable);
  @override
  String size(int bytes) => pseudo(super.size(bytes));
  @override
  String attachmentLabel(String name, int bytes) =>
      pseudo(super.attachmentLabel(name, bytes));
  @override
  String get sending => pseudo(super.sending);
  @override
  String get thinking => pseudo(super.thinking);
  @override
  String get writing => pseudo(super.writing);
  @override
  String get failed => pseudo(super.failed);
  @override
  String get stopped => pseudo(super.stopped);
  @override
  String get retry => pseudo(super.retry);
  @override
  String get newChat => pseudo(super.newChat);
  @override
  String get newChatTitle => pseudo(super.newChatTitle);
  @override
  String get newChatBody => pseudo(super.newChatBody);
  @override
  String get cancel => pseudo(super.cancel);
  @override
  String get delete => pseudo(super.delete);
  @override
  String get loadingOlder => pseudo(super.loadingOlder);
  @override
  String get newAnswer => pseudo(super.newAnswer);
  @override
  String get historyFailed => pseudo(super.historyFailed);
  @override
  String get loadingFailed => pseudo(super.loadingFailed);
  @override
  String asOf(String time) => pseudo(super.asOf(time));
  @override
  String get livePriceUnavailable => pseudo(super.livePriceUnavailable);
  @override
  String cardType(String type) => pseudo(super.cardType(type));
}

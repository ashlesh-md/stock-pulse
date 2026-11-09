/// Limits shared by the composer, the controller and local history.
abstract final class ChatLimits {
  static const maxQuestion = 200;
  static const maxAttachments = 3;
  static const maxAttachmentBytes = 5 * 1024 * 1024;
  static const maxAnswers = 50;
  static const bottomSlack = 48.0;
  static const loadAhead = 400.0;

  /// Answers per history page, on first open and on each scroll-up load.
  static const pageSize = 20;

  /// Stored history is capped by encoded size; the oldest answers go first.
  static const maxHistoryChars = 512 * 1024;
}

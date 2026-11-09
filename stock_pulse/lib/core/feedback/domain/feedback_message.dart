import 'package:flutter/foundation.dart';

/// Visual style of a message: icon and colour only.
enum FeedbackKind { info, success, error }

/// Which message wins the one snackbar slot: later values win.
enum FeedbackPriority { info, error, orderOutcome }

/// What the snackbar's action does. Data, not a closure, so messages stay
/// comparable.
sealed class FeedbackAction {
  const FeedbackAction();
}

/// Navigates to an app location, for example `/portfolio`.
final class OpenLocation extends FeedbackAction {
  const OpenLocation(this.path);

  final String path;

  @override
  bool operator ==(Object other) => other is OpenLocation && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Sends the tap back to the controller that showed the message, through
/// `FeedbackController.replies`.
final class ReplyToSender extends FeedbackAction {
  const ReplyToSender(this.actionId);

  final String actionId;

  @override
  bool operator ==(Object other) =>
      other is ReplyToSender && other.actionId == actionId;

  @override
  int get hashCode => actionId.hashCode;
}

/// A [ReplyToSender] tap on the message with [key].
@immutable
final class FeedbackReply {
  const FeedbackReply({required this.key, required this.actionId});

  final String key;
  final String actionId;

  @override
  bool operator ==(Object other) =>
      other is FeedbackReply && other.key == key && other.actionId == actionId;

  @override
  int get hashCode => Object.hash(key, actionId);
}

/// One snackbar message. [key] is its identity for dedupe, written
/// `<feature>.<reason>[.<id>]`, for example `orders.rejected.O-12`.
@immutable
final class FeedbackMessage {
  const FeedbackMessage({
    required this.key,
    required this.text,
    this.kind = FeedbackKind.info,
    this.actionLabel,
    this.action,
    this.persist = false,
    FeedbackPriority? priority,
  }) : priority =
           priority ??
           (kind == FeedbackKind.error
               ? FeedbackPriority.error
               : FeedbackPriority.info);

  final String key;

  /// Already localised.
  final String text;
  final FeedbackKind kind;
  final String? actionLabel;
  final FeedbackAction? action;

  /// Stays until dismissed or replaced (rejections, status unknown).
  final bool persist;
  final FeedbackPriority priority;

  @override
  bool operator ==(Object other) =>
      other is FeedbackMessage &&
      other.key == key &&
      other.text == text &&
      other.kind == kind &&
      other.actionLabel == actionLabel &&
      other.action == action &&
      other.persist == persist &&
      other.priority == priority;

  @override
  int get hashCode =>
      Object.hash(key, text, kind, actionLabel, action, persist, priority);

  @override
  String toString() => 'FeedbackMessage($key, $kind, $priority)';
}

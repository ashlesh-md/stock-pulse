import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/feedback/presentation/sp_snack.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// The one place that shows snackbars. Mount it above every route
/// (`MaterialApp.router(builder:)`) so a message survives route changes.
/// It never queues: a new message hides the current one first.
class FeedbackHost extends ConsumerStatefulWidget {
  const FeedbackHost({super.key, required this.child, this.onOpenLocation});

  final Widget child;

  /// Runs an [OpenLocation] action, normally `router.go`.
  final ValueChanged<String>? onOpenLocation;

  static const shortFor = Duration(seconds: 4);
  static const withActionFor = Duration(seconds: 6);

  /// Long enough to stay until the user dismisses it.
  static const persistFor = Duration(days: 1);

  @override
  ConsumerState<FeedbackHost> createState() => _FeedbackHostState();
}

class _FeedbackHostState extends ConsumerState<FeedbackHost> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(feedbackControllerProvider, (_, message) => _render(message));
    return ScaffoldMessenger(key: _messenger, child: widget.child);
  }

  void _render(FeedbackMessage? message) {
    final messenger = _messenger.currentState!..hideCurrentSnackBar();
    if (message == null) return;
    _announce(message.text);
    final shown = messenger.showSnackBar(_snackBar(message));
    unawaited(
      shown.closed.then((_) {
        if (mounted) {
          ref.read(feedbackControllerProvider.notifier).dismissed(message.key);
        }
      }),
    );
  }

  void _announce(String text) {
    final view = View.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(view, text, Directionality.of(context)),
    );
  }

  SnackBar _snackBar(FeedbackMessage message) {
    final hasAction = message.actionLabel != null && message.action != null;
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SpColors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(SpSpace.s4, 0, SpSpace.s4, SpSpace.s3),
      dismissDirection: DismissDirection.horizontal,
      persist: message.persist,
      duration: message.persist
          ? FeedbackHost.persistFor
          : hasAction
          ? FeedbackHost.withActionFor
          : FeedbackHost.shortFor,
      content: SpSnack(
        message: message,
        onAction: () {
          _messenger.currentState?.hideCurrentSnackBar(
            reason: SnackBarClosedReason.action,
          );
          _onAction(message);
        },
        onClose: () => _messenger.currentState?.hideCurrentSnackBar(
          reason: SnackBarClosedReason.dismiss,
        ),
      ),
    );
  }

  void _onAction(FeedbackMessage message) => switch (message.action) {
    OpenLocation(:final path) => widget.onOpenLocation?.call(path),
    ReplyToSender() ||
    null => ref.read(feedbackControllerProvider.notifier).actionTapped(message),
  };
}

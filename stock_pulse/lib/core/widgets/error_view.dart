import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';
import 'package:stock_pulse/core/widgets/empty_view.dart';

/// Error state with Retry for any [error] an `AsyncError` holds.
/// The server hint is for debug builds only.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return EmptyView(
      icon: AppIcons.offline,
      title: strings.errors.title,
      message: errorText(strings.errors, error),
      hint: kDebugMode ? strings.errors.serverHint : null,
      actionLabel: strings.common.retry,
      onAction: onRetry,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';

/// Modal bottom sheet: safe area, drag handle, at most 90 % of the
/// screen, scroll-controlled. Counts itself in `openSheetCountProvider` while
/// open, so app-level banners can wait.
Future<T?> showSpSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? maxHeight,
  double? maxWidth,
  bool enableDrag = true,
  bool isDismissible = true,
}) async {
  final container = _containerOf(context);
  final count = container?.read(openSheetCountProvider.notifier);
  count?.inc();
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      constraints: maxWidth == null
          ? BoxConstraints(
              maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.9,
            )
          : BoxConstraints(
              maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.9,
              maxWidth: maxWidth,
            ),
      builder: builder,
    );
  } finally {
    count?.dec();
  }
}

ProviderContainer? _containerOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false);
  } on StateError {
    // The shared widget library also works outside the Riverpod app shell.
    return null;
  }
}

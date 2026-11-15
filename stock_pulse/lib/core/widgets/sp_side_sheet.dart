import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<T?> showSpSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
  pageBuilder: (context, _, _) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: math.min(360, MediaQuery.sizeOf(context).width),
      height: MediaQuery.sizeOf(context).height,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(child: Builder(builder: builder)),
      ),
    ),
  ),
);

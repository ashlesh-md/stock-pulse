import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stock_pulse/core/theme/app_theme.dart';

/// `ProviderScope` + `MaterialApp` with the real theme (the Sp extensions are
/// required by every core widget), [child] in a Scaffold body.
Widget spApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
}) => ProviderScope(
  overrides: overrides,
  retry: (_, _) => null,
  child: MaterialApp(
    theme: theme ?? AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  ),
);

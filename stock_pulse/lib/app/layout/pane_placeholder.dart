import 'package:flutter/material.dart';

/// The empty detail pane of an `AdaptiveTwoPane` before anything is picked.
class PanePlaceholder extends StatelessWidget {
  const PanePlaceholder({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 48, color: muted)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

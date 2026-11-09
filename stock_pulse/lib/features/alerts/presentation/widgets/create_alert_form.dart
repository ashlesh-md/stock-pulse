import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/alerts/di/alerts_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

class CreateAlertForm extends ConsumerStatefulWidget {
  const CreateAlertForm({super.key, this.onCreated});
  final VoidCallback? onCreated;
  @override
  ConsumerState<CreateAlertForm> createState() => _CreateAlertFormState();
}

class _CreateAlertFormState extends ConsumerState<CreateAlertForm> {
  final _symbol = TextEditingController();
  final _price = TextEditingController();
  AlertCondition _condition = AlertCondition.above;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _symbol.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.alerts;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.create,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.sp.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.dismiss,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              const SizedBox(height: SpSpace.s3),
              TextField(
                controller: _symbol,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s.symbol,
                  prefixIcon: const Icon(AppIcons.watchlist),
                ),
              ),
              const SizedBox(height: SpSpace.s3),
              TextField(
                controller: _price,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: s.level,
                  prefixText: '₹ ',
                  prefixIcon: const Icon(AppIcons.target),
                ),
              ),
              const SizedBox(height: SpSpace.s3),
              SpPicker<AlertCondition>(
                title: s.condition,
                values: AlertCondition.values,
                label: (condition) => switch (condition) {
                  AlertCondition.above => s.above,
                  AlertCondition.below => s.below,
                },
                selected: _condition,
                enabled: !_busy,
                onChanged: (condition) =>
                    setState(() => _condition = condition),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: SpSpace.s2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SpSpace.s4),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final price = double.tryParse(_price.text);
                        if (_symbol.text.trim().isEmpty ||
                            price == null ||
                            !price.isFinite ||
                            price <= 0) {
                          setState(() => _error = s.invalid);
                          return;
                        }
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        final success = await ref
                            .read(alertsControllerProvider.notifier)
                            .create(_symbol.text.trim(), _condition, price);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                          widget.onCreated?.call();
                          return;
                        }
                        setState(() {
                          _busy = false;
                          _error = s.failed;
                        });
                      },
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.success),
                label: Text(s.create),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

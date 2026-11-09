import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/layout/window_class.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/more/di/funds_providers.dart';
import 'package:stock_pulse/features/more/domain/funds_limits.dart';
import 'package:stock_pulse/features/more/presentation/widgets/payment_method_picker.dart';
import 'package:stock_pulse/features/more/presentation/widgets/quick_amount_chips.dart';

/// Simulated deposit: amount, quick amounts, method, confirm. The server
/// credits the demo account and the portfolio's funds update over the socket.
class AddFundsScreen extends ConsumerStatefulWidget {
  const AddFundsScreen({super.key});

  @override
  ConsumerState<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends ConsumerState<AddFundsScreen> {
  final _amount = TextEditingController(text: '1000');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _confirm() => ref
      .read(addFundsControllerProvider.notifier)
      .submit(double.tryParse(_amount.text.trim()));

  @override
  Widget build(BuildContext context) {
    final s = context.strings.more;
    final state = ref.watch(addFundsControllerProvider);
    final busy = state.submitting;
    final controller = ref.read(addFundsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(s.addFunds)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.form),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(s.simulatedPayment),
              const SizedBox(height: 24),
              TextField(
                controller: _amount,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: busy ? null : (_) => _confirm(),
                decoration: InputDecoration(
                  labelText: s.amount,
                  errorText: state.invalidAmount
                      ? s.amountInvalid(Fmt.price(FundsLimits.maxDeposit))
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              QuickAmountChips(
                onPicked: busy
                    ? null
                    : (amount) => _amount.text = amount.toStringAsFixed(0),
              ),
              const SizedBox(height: 24),
              PaymentMethodPicker(
                selected: state.method,
                onChanged: busy ? null : controller.selectMethod,
              ),
              const SizedBox(height: 24),
              if (state.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.fundsFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (state.funds case final funds?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(s.fundsAdded(Fmt.price(funds.available))),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : _confirm,
                child: busy
                    ? SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          semanticsLabel: s.confirmFunds,
                        ),
                      )
                    : Text(s.confirmFunds),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

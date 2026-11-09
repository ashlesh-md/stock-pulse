import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';

class RiskNoticePanel extends StatefulWidget {
  const RiskNoticePanel({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  State<RiskNoticePanel> createState() => _RiskNoticePanelState();
}

class _RiskNoticePanelState extends State<RiskNoticePanel> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    final s = context.strings.orders;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.riskTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(s.riskBody),
            CheckboxListTile(
              value: _checked,
              title: Text(s.riskAgree),
              onChanged: (checked) =>
                  setState(() => _checked = checked ?? false),
            ),
            FilledButton(
              onPressed: _checked ? widget.onContinue : null,
              child: Text(s.riskContinue),
            ),
          ],
        ),
      ),
    );
  }
}

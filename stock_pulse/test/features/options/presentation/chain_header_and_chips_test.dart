import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_cell_sheet.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_header.dart';
import 'package:stock_pulse/features/options/presentation/widgets/expiry_chips.dart';
import 'package:stock_pulse/features/options/presentation/widgets/option_side_cell.dart';

import '../../../helpers/sp_app.dart';

const _all = {ChainColumn.oi, ChainColumn.oiChange, ChainColumn.ltp};

const _cell = OptionCell(
  contractId: 'NIFTY24500PE',
  ltp: 141.25,
  change: 1,
  oi: 800000,
  oiChange: -300,
);

List<String> _leftToRight(WidgetTester tester, Finder texts) {
  final found = texts.evaluate().toList()
    ..sort(
      (a, b) => tester
          .getCenter(find.byWidget(a.widget))
          .dx
          .compareTo(tester.getCenter(find.byWidget(b.widget)).dx),
    );
  return [for (final e in found) (e.widget as Text).data!];
}

Expiry _expiry(String code, {bool today = false}) => Expiry(
  code: code,
  expiryAt: DateTime.utc(2026, 11, 9, 10),
  kind: ExpiryKind.weekly,
  isToday: today,
);

void main() {
  testWidgets('contract sheet actions stay compact and tap-sized', (
    tester,
  ) async {
    await tester.pumpWidget(spApp(const ChainCellSheet(cell: _cell)));
    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons, hasLength(2));
    for (final button in find.byType(FilledButton).evaluate()) {
      final size = tester.getSize(find.byWidget(button.widget));
      expect(size.width, lessThanOrEqualTo(128));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  test('chainSideColumns mirrors puts so both LTPs face the strike', () {
    expect(chainSideColumns(_all, call: true), [
      ChainColumn.oi,
      ChainColumn.oiChange,
      ChainColumn.ltp,
    ]);
    expect(chainSideColumns(_all, call: false), [
      ChainColumn.ltp,
      ChainColumn.oiChange,
      ChainColumn.oi,
    ]);
  });

  testWidgets('B9: the puts header reads LTP · ΔOI · OI like its values', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(const SizedBox(width: 600, child: ChainHeader(columns: _all))),
    );
    final labels = _leftToRight(
      tester,
      find.byWidgetPredicate(
        (w) => w is Text && const {'OI', 'ΔOI', 'LTP'}.contains(w.data),
      ),
    );
    expect(labels, ['OI', 'ΔOI', 'LTP', 'LTP', 'ΔOI', 'OI']);
  });

  testWidgets('B9: a put cell shows LTP first and OI last', (tester) async {
    await tester.pumpWidget(
      spApp(
        SizedBox(
          width: 300,
          height: 48,
          child: OptionSideCell(
            cell: _cell,
            call: false,
            strike: 24500,
            itm: false,
            maxOi: 800000,
            columns: _all,
            onTap: (_) {},
          ),
        ),
      ),
    );
    final values = _leftToRight(tester, find.byType(Text));
    expect(values, ['141.25', '−300', '8.00L']);
  });

  testWidgets('B11: the selected today chip has an onAccent tag on accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        SizedBox(
          width: 400,
          child: ExpiryChips(
            expiries: [
              _expiry('2026-11-09', today: true),
              _expiry('2026-11-16'),
            ],
            selected: '2026-11-09',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    final sp = AppTheme.dark().extension<SpColors>()!;
    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
    expect(chip.selectedColor, sp.accent);
    final tag = _tag(tester, '9 Nov  Expires today');
    expect(tag.style!.color, sp.onAccent);
    expect(_contrast(sp.onAccent, sp.accent), greaterThanOrEqualTo(4.5));

    final other = _tag(tester, '16 Nov  Weekly');
    expect(other.style!.color, sp.textSecondary);
  });

  testWidgets('B11: an unselected today chip keeps the warn tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        ExpiryChips(
          expiries: [_expiry('2026-11-09', today: true)],
          selected: 'other',
          onSelected: (_) {},
        ),
      ),
    );
    final sp = AppTheme.dark().extension<SpColors>()!;
    final tag = _tag(tester, '9 Nov  Expires today');
    expect(tag.style!.color, sp.warn);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + .05;
  final lb = b.computeLuminance() + .05;
  return la > lb ? la / lb : lb / la;
}

TextSpan _tag(WidgetTester tester, String label) {
  TextSpan? tag;
  tester
      .widget<RichText>(find.text(label, findRichText: true))
      .text
      .visitChildren((span) {
        if (span is TextSpan && (span.text?.startsWith('  ') ?? false)) {
          tag = span;
        }
        return true;
      });
  return tag!;
}

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

/// `9 Nov` from an expiry code such as `2026-11-09`; the code is a market
/// date, so it is read without a time zone shift.
String expiryLabel(Expiry expiry) => Fmt.dayMonth(DateTime.parse(expiry.code));

/// One chip per expiry: the date, then `Expires today` or Weekly/Monthly.
class ExpiryChips extends StatelessWidget {
  const ExpiryChips({
    super.key,
    required this.expiries,
    required this.selected,
    required this.onSelected,
  });

  final List<Expiry> expiries;
  final String selected;
  final ValueChanged<Expiry> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.options;
    final sp = context.sp;
    return SizedBox(
      height: SpDensity.tap + SpSpace.s2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpSpace.gutter),
        itemCount: expiries.length,
        separatorBuilder: (_, _) => const SizedBox(width: SpSpace.s2),
        itemBuilder: (context, index) {
          final e = expiries[index];
          final tag = e.isToday
              ? s.expiresToday
              : switch (e.kind) {
                  ExpiryKind.weekly => s.weekly,
                  ExpiryKind.monthly => s.monthly,
                };
          final active = e.code == selected;
          return Center(
            child: ChoiceChip(
              selected: active,
              showCheckmark: false,
              selectedColor: sp.accent,
              onSelected: (_) => onSelected(e),
              label: Text.rich(
                TextSpan(
                  text: expiryLabel(e),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? sp.onAccent : null,
                  ),
                  children: [
                    TextSpan(
                      text: '  $tag',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: _tagColor(sp, active: active, today: e.isToday),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// On the selected chip the tag takes the chip's own text colour: warn on
/// accent fails contrast.
Color _tagColor(SpColors sp, {required bool active, required bool today}) =>
    active
    ? sp.onAccent
    : today
    ? sp.warn
    : sp.textSecondary;

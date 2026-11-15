import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/app_strings.dart';

void main() {
  test(
    'chart actions have distinct localized labels and explain drawing limits',
    () {
      final s = appStringsFor(defaultLocale).chart;
      final labels = [
        s.draw,
        s.horizontal,
        s.trend,
        s.fibonacci,
        s.cancel,
        s.delete,
        s.expand,
        s.exit,
        s.settings,
        s.logScale,
        s.gridlines,
        s.empty,
        s.setAlert,
        s.buyLimit,
        s.sellLimit,
      ];
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
      expect(labels.toSet(), hasLength(labels.length));
      expect(s.limit, contains('20'));
      expect(s.saveFailed, "Couldn't save drawing");
    },
  );
}

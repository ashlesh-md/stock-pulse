import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/strings/chat_strings.dart';
import 'package:stock_pulse/core/l10n/strings/studies_strings.dart';

void main() {
  test('chat attachment sizes and labels cover KB and MB formatting', () {
    const strings = ChatStrings();
    expect(strings.size(1), '1 KB');
    expect(strings.size(1024 * 1024), '1.0 MB');
    expect(strings.attachmentLabel('chart.png', 1024), 'chart.png, 1 KB');
    expect(strings.cardType('unknown'), 'Explanation');
    expect(strings.counter(3, 10), '3/10');
  });

  test('study names map known kinds and preserve unknown kinds', () {
    const strings = StudiesStrings();
    expect(strings.name('sma'), 'SMA');
    expect(strings.name('experimental'), 'EXPERIMENTAL');
  });
}

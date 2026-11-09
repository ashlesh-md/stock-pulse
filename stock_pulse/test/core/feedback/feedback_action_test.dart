import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';

void main() {
  test('actions built at runtime compare by their target', () {
    final path = ['/', 'portfolio'].join();
    final id = ['retry', '-1'].join();

    expect(OpenLocation(path), const OpenLocation('/portfolio'));
    expect(
      OpenLocation(path).hashCode,
      const OpenLocation('/portfolio').hashCode,
    );
    expect(ReplyToSender(id), const ReplyToSender('retry-1'));
    expect(ReplyToSender(id).hashCode, const ReplyToSender('retry-1').hashCode);
    expect(OpenLocation(path) == ReplyToSender(path), isFalse);
  });
}

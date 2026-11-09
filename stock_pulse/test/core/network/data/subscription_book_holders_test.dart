import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/subscription_book.dart';
import 'package:stock_pulse/core/network/domain/socket_ops.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

void main() {
  test(
    'removing one of three holders keeps the strongest remaining request',
    () {
      final ltp = SocketSubscription(['TCS'], FeedMode.ltp, throttleMs: 1000);
      final quote = SocketSubscription(
        ['TCS'],
        FeedMode.quote,
        throttleMs: 300,
      );
      final full = SocketSubscription(['TCS'], FeedMode.full, throttleMs: 100);
      final book = SubscriptionBook()
        ..addQuotes(quote)
        ..addQuotes(ltp)
        ..addQuotes(full);
      book.pendingOps();

      final lingering = book.removeQuotes(full, lingerLastHolder: true);

      expect(lingering, isEmpty);
      final reduced = book.pendingOps().single as SubscribeQuotes;
      expect((reduced.mode, reduced.throttleMs), (FeedMode.quote, 300));
    },
  );
}

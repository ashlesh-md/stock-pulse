import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/subscription_book.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_ops.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

ChainSubscription _chain(int from, int to, {String expiry = '2026-11-10'}) =>
    ChainSubscription(
      ChainRequest(
        underlying: 'NIFTY',
        expiry: expiry,
        fromStrike: from,
        toStrike: to,
      ),
    );

void main() {
  test('quote holders choose max mode and min throttle', () {
    final watchlist = SocketSubscription(
      ['TCS'],
      FeedMode.quote,
      throttleMs: 600,
    );
    final detail = SocketSubscription(['TCS'], FeedMode.full, throttleMs: 100);
    final book = SubscriptionBook()
      ..addQuotes(watchlist)
      ..addQuotes(detail);

    final subscribe = book.pendingOps().single as SubscribeQuotes;
    expect((subscribe.mode, subscribe.throttleMs), (FeedMode.full, 100));

    book.removeQuotes(detail, lingerLastHolder: false);
    final reduced = book.pendingOps().single as SubscribeQuotes;
    expect((reduced.mode, reduced.throttleMs), (FeedMode.quote, 600));
  });

  test(
    'quote aggregation keeps the existing mode and throttle when stricter',
    () {
      final full = SocketSubscription(['INFY'], FeedMode.full, throttleMs: 100);
      final slower = SocketSubscription(
        ['INFY'],
        FeedMode.quote,
        throttleMs: 600,
      );
      final removed = SocketSubscription(
        ['INFY'],
        FeedMode.ltp,
        throttleMs: 300,
      );
      final book = SubscriptionBook()
        ..addQuotes(full)
        ..addQuotes(slower)
        ..addQuotes(removed);
      final subscribe = book.pendingOps().single as SubscribeQuotes;
      expect((subscribe.mode, subscribe.throttleMs), (FeedMode.full, 100));
      expect(book.removeQuotes(removed, lingerLastHolder: false), isEmpty);
    },
  );

  test('removing a holder without server state does not create a linger', () {
    final holder = SocketSubscription(['TCS'], FeedMode.ltp);
    final book = SubscriptionBook()..addQuotes(holder);
    expect(book.removeQuotes(holder, lingerLastHolder: true), isEmpty);
  });

  test('two holders of one chain share one subscription over both ranges', () {
    final book = SubscriptionBook()
      ..addChain(_chain(100, 200))
      ..addChain(_chain(150, 300));
    final ops = book.pendingOps().whereType<SubscribeChain>().single;
    expect((ops.from, ops.to), (100, 300));
    expect(book.pendingOps(), isEmpty);
  });

  test('a reconnect replays chains; removing the last one unsubscribes', () {
    final holder = _chain(100, 200);
    final book = SubscriptionBook()..addChain(holder);
    book.pendingOps();
    book.forgetServerState();
    expect(book.pendingOps().single, isA<SubscribeChain>());

    book.removeChain(holder);
    final op = book.pendingOps().single as UnsubscribeChain;
    expect(op.toJson(), containsPair('expiry', '2026-11-10'));
  });
}

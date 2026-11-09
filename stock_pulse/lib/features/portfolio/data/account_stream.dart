import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';

/// Attach before fetching REST so an account change during the request is
/// retained. A sequence gap or reconnect fetches a fresh account baseline.
Stream<T> accountStream<T>({
  required MarketSocket socket,
  required String type,
  required T Function(Map<String, Object?>) parse,
  required Future<Result<T>> Function() fetch,
  T Function(T current, T incoming)? merge,
  T Function(T current, T snapshot)? reconcileSnapshot,
}) => Stream<T>.multi((controller) {
  var active = true;
  T? current;
  List<T>? queuedMessages;
  Future<void>? reloadTask;

  void applyUpdate(T value) {
    if (!active) return;
    current = current == null || merge == null
        ? value
        : merge(current as T, value);
    controller.addSync(current as T);
  }

  void emitMessage(T value) {
    if (!active) return;
    final queue = queuedMessages;
    if (queue != null) {
      queue.add(value);
      return;
    }
    applyUpdate(value);
  }

  Future<void> reloadFromSnapshot() async {
    final updatesDuringFetch = <T>[];
    queuedMessages = updatesDuringFetch;
    final result = await fetch();
    if (!active) return;
    switch (result) {
      case Success(:final value):
        final snapshot = current != null && reconcileSnapshot != null
            ? reconcileSnapshot(current as T, value)
            : value;
        current = snapshot;
        controller.addSync(snapshot);
      case Failure(:final error):
        controller.addErrorSync(error);
    }
    queuedMessages = null;
    for (final update in updatesDuringFetch) {
      applyUpdate(update);
    }
  }

  Future<void> reload() => reloadTask ??= reloadFromSnapshot().whenComplete(() {
    reloadTask = null;
  });

  final account = socket.subscribeAccount(alerts: false);
  final messages = socket.messages.where((m) => m['type'] == type).listen((m) {
    switch (parseJson(() => parse(m['data']! as Map<String, Object?>))) {
      case Success(:final value):
        emitMessage(value);
      case Failure(:final error):
        controller.addErrorSync(error);
    }
  });
  final removeReloader = socket.registerResyncReloader(reload);
  unawaited(reload());
  controller.onCancel = () async {
    active = false;
    account.cancel();
    removeReloader();
    await messages.cancel();
  };
});

import 'dart:convert';

import 'package:market_server/src/broker.dart';
import 'package:market_server/src/ws_session.dart';

class ChainSub {
  ChainSub(this.underlying, this.expiry, this.from, this.to);
  final String underlying;
  final String expiry;
  final int from;
  final int to;
  final lastRows = <int, String>{};
  DateTime? lastSentAt;
  double? lastSpot;
  int? lastAtm;
  String? lastStatus;
  String get id => '$underlying:$expiry';
}

extension WsChains on WsSession {
  void changeChain(
    Map<String, Object?> message,
    Object? requestId, {
    required bool subscribe,
  }) {
    final underlying = message['underlying'];
    final expiry = message['expiry'];
    final from = message['fromStrike'];
    final to = message['toStrike'];
    if (underlying is! String ||
        expiry is! String ||
        (subscribe && (from is! int || to is! int || from > to))) {
      sendError(
        'invalid_chain',
        'Need underlying, expiry and ordered strike range',
        id: requestId,
      );
      return;
    }
    final id = '$underlying:$expiry';
    if (subscribe && !chains.containsKey(id) && chains.length >= 2) {
      sendError(
        'too_many_chains',
        'At most two chains per session',
        id: requestId,
      );
      return;
    }
    if (!subscribe) {
      chains.remove(id);
      send({
        'type': 'ack',
        'id': requestId,
        'op': 'unsubscribe',
        'channel': 'chain',
        'chainId': id,
      });
      return;
    }
    final sub = ChainSub(underlying, expiry, from! as int, to! as int);
    try {
      final chain = gateway.options?.chain(
        underlying,
        expiry,
        from: sub.from,
        to: sub.to,
      );
      if (chain == null) {
        throw const OrderRejection(
          'unknown_chain',
          'Chain service unavailable',
          status: 404,
        );
      }
      chains[id] = sub;
      send({
        'type': 'ack',
        'id': requestId,
        'op': 'subscribe',
        'channel': 'chain',
        'chainId': id,
      });
      sendData('chain', {...chain, 'kind': 'snapshot'});
      _rememberChain(sub, chain, gateway.clock.wallNow());
    } on OrderRejection catch (e) {
      sendError(e.code, e.message, id: requestId);
    }
  }

  void flushChains({bool snapshot = false}) {
    for (final sub in chains.values) {
      if (gateway.isIdFrozen(sub.underlying)) continue;
      final live = gateway.options?.chain(
        sub.underlying,
        sub.expiry,
        from: sub.from,
        to: sub.to,
      );
      if (live == null) continue;
      final chain = _withoutFrozen(sub, live);
      final now = gateway.clock.wallNow();
      final rows = (chain['rows']! as List).cast<Map<String, Object?>>();
      final changedRows = [
        for (final row in rows)
          if (sub.lastRows[row['strike']! as int] != jsonEncode(row)) row,
      ];
      final headerChanged =
          sub.lastSpot != chain['spot'] ||
          sub.lastAtm != chain['atm'] ||
          sub.lastStatus != chain['status'];
      if (!snapshot && changedRows.isEmpty && !headerChanged) continue;
      final sentAt = sub.lastSentAt;
      if (!snapshot &&
          sentAt != null &&
          now.difference(sentAt) < const Duration(seconds: 1)) {
        continue;
      }
      sendData('chain', {
        ...chain,
        if (!snapshot) 'rows': changedRows,
        'kind': snapshot ? 'snapshot' : 'delta',
      });
      _rememberChain(sub, chain, now);
    }
  }

  /// Drops frozen contract cells and lists them in `ex` with the chain's
  /// last sent `asOf`, so they go out again with current values once the
  /// freeze ends.
  Map<String, Object?> _withoutFrozen(
    ChainSub sub,
    Map<String, Object?> chain,
  ) {
    final ex = <String, int>{};
    final rows = <Map<String, Object?>>[];
    for (final row in (chain['rows']! as List).cast<Map<String, Object?>>()) {
      final kept = <String, Object?>{};
      for (final MapEntry(:key, :value) in row.entries) {
        final id = value is Map ? value['contractId'] : null;
        if (id is String && gateway.isIdFrozen(id)) {
          ex[id] = sub.lastSentAt?.millisecondsSinceEpoch ?? 0;
        } else {
          kept[key] = value;
        }
      }
      rows.add(kept);
    }
    return {...chain, 'rows': rows, if (ex.isNotEmpty) 'ex': ex};
  }

  void _rememberChain(ChainSub sub, Map<String, Object?> chain, DateTime now) {
    sub.lastRows
      ..clear()
      ..addEntries(
        (chain['rows']! as List).cast<Map<String, Object?>>().map(
          (row) => MapEntry(row['strike']! as int, jsonEncode(row)),
        ),
      );
    sub
      ..lastSentAt = now
      ..lastSpot = (chain['spot']! as num).toDouble()
      ..lastAtm = chain['atm']! as int
      ..lastStatus = chain['status']! as String;
  }
}

import 'dart:convert';

import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';
import 'package:stock_pulse/features/orders/domain/pending_order_store.dart';

class LocalPendingOrderStore implements PendingOrderStore {
  LocalPendingOrderStore(this._prefs);

  final LocalPrefs _prefs;

  @override
  Future<List<PendingOrder>> readAll() async {
    final result = <PendingOrder>[];
    for (final record in _prefs.data.pendingOrderRecords) {
      try {
        result.add(
          PendingOrder.fromJson(jsonDecode(record) as Map<String, Object?>),
        );
      } on Object {
        // Ignore a damaged pending row without discarding the user's settings.
      }
    }
    return result;
  }

  @override
  Future<void> put(PendingOrder order) => _prefs.update((current) {
    final records = [
      for (final record in current.pendingOrderRecords)
        if (!_hasKey(record, order.clientKey)) record,
      jsonEncode(order.toJson()),
    ];
    return current.copyWith(pendingOrderRecords: records);
  });

  @override
  Future<void> remove(String clientKey) => _prefs.update((current) {
    final records = [
      for (final record in current.pendingOrderRecords)
        if (!_hasKey(record, clientKey)) record,
    ];
    return current.copyWith(pendingOrderRecords: records);
  });

  bool _hasKey(String record, String clientKey) {
    try {
      return (jsonDecode(record) as Map<String, Object?>)['clientKey'] ==
          clientKey;
    } on Object {
      return false;
    }
  }
}

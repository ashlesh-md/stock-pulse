import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

@immutable
class ChainState {
  const ChainState({
    required this.expiries,
    required this.expiry,
    required this.view,
  });
  final List<Expiry> expiries;
  final String expiry;
  final ChainView? view;
  ChainState copyWith({ChainView? view}) =>
      ChainState(expiries: expiries, expiry: expiry, view: view ?? this.view);
  @override
  bool operator ==(Object other) =>
      other is ChainState &&
      listEquals(other.expiries, expiries) &&
      other.expiry == expiry &&
      other.view == view;
  @override
  int get hashCode => Object.hash(Object.hashAll(expiries), expiry, view);
}

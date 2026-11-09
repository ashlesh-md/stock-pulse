import 'package:market_server/src/models.dart';

/// What the gateway, broker and alerts need from anything with a live price:
/// equities, the index and later option contracts. `engine[id]` returns one
/// of these.
abstract interface class Tradable {
  String get id;
  InstrumentKind get kind;
  double get ltp;
  double get prevClose;
  double get change;
  double get changePercent;
  DateTime get lastTradeTime;
}

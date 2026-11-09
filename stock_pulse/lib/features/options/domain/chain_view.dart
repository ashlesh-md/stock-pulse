import 'package:meta/meta.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';

/// One CE or PE cell. No `asOf`: freshness comes from [ChainView.asOfFor].
@immutable
class OptionCell {
  const OptionCell({
    required this.contractId,
    required this.ltp,
    required this.change,
    required this.oi,
    required this.oiChange,
    this.iv,
    this.delta,
  });

  final String contractId;
  final double ltp;
  final double change;
  final int oi;
  final int oiChange;

  /// Percent, e.g. 13.42. Populated after the first snapshot.
  final double? iv;
  final double? delta;

  OptionCell copyWith({
    double? ltp,
    double? change,
    int? oi,
    int? oiChange,
    double? iv,
    double? delta,
  }) => OptionCell(
    contractId: contractId,
    ltp: ltp ?? this.ltp,
    change: change ?? this.change,
    oi: oi ?? this.oi,
    oiChange: oiChange ?? this.oiChange,
    iv: iv ?? this.iv,
    delta: delta ?? this.delta,
  );

  @override
  bool operator ==(Object other) =>
      other is OptionCell &&
      other.contractId == contractId &&
      other.ltp == ltp &&
      other.change == change &&
      other.oi == oi &&
      other.oiChange == oiChange &&
      other.iv == iv &&
      other.delta == delta;

  @override
  int get hashCode =>
      Object.hash(contractId, ltp, change, oi, oiChange, iv, delta);
}

@immutable
class ChainRow {
  const ChainRow({required this.strike, this.ce, this.pe});

  final int strike;
  final OptionCell? ce;
  final OptionCell? pe;

  ChainRow copyWith({OptionCell? ce, OptionCell? pe}) =>
      ChainRow(strike: strike, ce: ce ?? this.ce, pe: pe ?? this.pe);

  @override
  bool operator ==(Object other) =>
      other is ChainRow &&
      other.strike == strike &&
      other.ce == ce &&
      other.pe == pe;

  @override
  int get hashCode => Object.hash(strike, ce, pe);
}

/// A folded chain. Rows are rebuilt only when changed, so `==` compares
/// row identity and controllers can `select` a row by strike.
@immutable
class ChainView {
  const ChainView({
    required this.chainId,
    required this.seq,
    required this.asOf,
    required this.spot,
    required this.atm,
    required this.status,
    required this.strikes,
    required this.rows,
    this.exAsOf = const {},
  });

  final String chainId;
  final int seq;

  /// Last confirmation of the subscribed range.
  final DateTime asOf;
  final double spot;
  final int atm;
  final ChainStatus status;
  final List<int> strikes;
  final Map<int, ChainRow> rows;

  /// Cells not confirmed by the last frame (frozen, out of range).
  final Map<String, DateTime> exAsOf;

  DateTime asOfFor(String contractId) => exAsOf[contractId] ?? asOf;

  ChainView copyWith({
    int? seq,
    DateTime? asOf,
    double? spot,
    int? atm,
    ChainStatus? status,
    List<int>? strikes,
    Map<int, ChainRow>? rows,
    Map<String, DateTime>? exAsOf,
  }) => ChainView(
    chainId: chainId,
    seq: seq ?? this.seq,
    asOf: asOf ?? this.asOf,
    spot: spot ?? this.spot,
    atm: atm ?? this.atm,
    status: status ?? this.status,
    strikes: strikes ?? this.strikes,
    rows: rows ?? this.rows,
    exAsOf: exAsOf ?? this.exAsOf,
  );

  @override
  bool operator ==(Object other) =>
      other is ChainView &&
      other.chainId == chainId &&
      other.seq == seq &&
      other.status == status &&
      other.spot == spot &&
      other.atm == atm &&
      _sameRows(other.rows, rows);

  @override
  int get hashCode => Object.hash(chainId, seq, status, spot, atm);

  static bool _sameRows(Map<int, ChainRow> a, Map<int, ChainRow> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!identical(b[e.key], e.value)) return false;
    }
    return true;
  }
}

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// The latest merged account book, read by dev-perf's SnapshotScheduler.
@immutable
class PortfolioBook {
  PortfolioBook({
    required List<Position> positions,
    required List<Holding> holdings,
    this.funds,
  }) : positions = List.unmodifiable(positions),
       holdings = List.unmodifiable(holdings);

  final List<Position> positions;
  final List<Holding> holdings;
  final Funds? funds;

  @override
  bool operator ==(Object other) =>
      other is PortfolioBook &&
      const ListEquality<Object?>().equals(other.positions, positions) &&
      const ListEquality<Object?>().equals(other.holdings, holdings) &&
      other.funds == funds;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(positions), Object.hashAll(holdings), funds);
}

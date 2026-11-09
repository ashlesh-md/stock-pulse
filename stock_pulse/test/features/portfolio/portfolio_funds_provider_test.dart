import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

class _Portfolio extends Fake implements PortfolioRepository {
  _Portfolio(this.funds);

  final Stream<Funds> funds;

  @override
  Stream<Funds> watchFunds() => funds;
}

void main() {
  test('portfolio funds provider forwards live account updates', () async {
    final updates = StreamController<Funds>.broadcast(sync: true);
    addTearDown(updates.close);
    final repository = _Portfolio(updates.stream);
    final container = ProviderContainer.test(
      overrides: [portfolioRepositoryProvider.overrideWithValue(repository)],
    );
    final values = <Funds>[];
    final subscription = container.listen(portfolioFundsProvider, (_, next) {
      if (next case AsyncData(:final value)) values.add(value);
    });

    const first = Funds(available: 5000, version: 1);
    const second = Funds(available: 2500, version: 2);
    updates
      ..add(first)
      ..add(second);
    await Future<void>.delayed(Duration.zero);

    expect(values, [first, second]);
    subscription.close();
  });
}

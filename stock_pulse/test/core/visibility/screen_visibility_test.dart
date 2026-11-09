import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer.test());

  bool visible(ScreenId id) => container.read(screenVisibleProvider(id));
  void mirror(int index) =>
      container.read(selectedTabProvider.notifier).mirror(index);

  test('kTabs is the five shell tabs in bar order', () {
    expect(kTabs, [
      ScreenId.watchlist,
      ScreenId.options,
      ScreenId.ai,
      ScreenId.portfolio,
      ScreenId.more,
    ]);
  });

  test('the selected tab starts on watchlist and mirrors a branch index', () {
    expect(container.read(selectedTabProvider), ScreenId.watchlist);

    mirror(3);

    expect(container.read(selectedTabProvider), ScreenId.portfolio);
  });

  test('mirror rejects an index outside the tabs', () {
    expect(() => mirror(5), throwsRangeError);
  });

  test('FR-86: only the selected tab is visible', () {
    expect(visible(ScreenId.watchlist), isTrue);
    expect(visible(ScreenId.options), isFalse);

    mirror(1);

    expect(visible(ScreenId.watchlist), isFalse);
    expect(visible(ScreenId.options), isTrue);
  });

  test('an opaque cover hides the selected tab and shows only its top', () {
    container
        .read(coveredStateProvider.notifier)
        .set(
          const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 2),
        );

    expect(visible(ScreenId.watchlist), isFalse);
    expect(visible(ScreenId.stockDetail), isTrue);
    expect(visible(ScreenId.alerts), isFalse);
  });

  test('a routed screen is hidden while the shell is on top', () {
    expect(visible(ScreenId.stockDetail), isFalse);
    expect(visible(ScreenId.strategy), isFalse);
  });

  test('NFR-14: listeners hear a tab hide and show', () async {
    final seen = <bool>[];
    container.listen(
      screenVisibleProvider(ScreenId.portfolio),
      (_, next) => seen.add(next),
    );

    mirror(3);
    await container.pump();
    mirror(4);
    await container.pump();

    expect(seen, [true, false]);
  });

  test('CoveredState is a value', () {
    const a = CoveredState(topOpaque: ScreenId.alerts, opaqueDepth: 1);
    const b = CoveredState(topOpaque: ScreenId.alerts, opaqueDepth: 1);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == CoveredState.shell, isFalse);
    expect(
      a.toString(),
      'CoveredState(topOpaque: ScreenId.alerts, opaqueDepth: 1)',
    );
  });
}

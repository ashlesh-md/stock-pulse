import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/core/visibility/presentation/visibility_route_observer.dart';

/// A root navigator whose first page is named like the router's shell page,
/// watched by a [VisibilityRouteObserver].
class VisibilityHarness {
  VisibilityHarness() {
    observer = VisibilityRouteObserver(
      container.read(coveredStateProvider.notifier),
    );
  }

  final container = ProviderContainer();
  final navigatorKey = GlobalKey<NavigatorState>();
  late final VisibilityRouteObserver observer;

  NavigatorState get navigator => navigatorKey.currentState!;

  bool visible(ScreenId id) => container.read(screenVisibleProvider(id));

  Widget app({List<String> initialPages = const [kShellPageName]}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [observer],
          onGenerateRoute: (_) => null,
          onGenerateInitialRoutes: (_) => [
            for (final n in initialPages) page(n),
          ],
        ),
      );

  static MaterialPageRoute<void> page(String name) => MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => Scaffold(body: Text(name)),
  );

  /// An opaque page; [id] null = a screen with no ScreenId (risk notice).
  Future<void> pushPage(ScreenId? id) =>
      navigator.push(page(id?.name ?? 'riskNotice'));
}

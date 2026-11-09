import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/app/alert_banner_host.dart';
import 'package:stock_pulse/app/app_lifecycle_host.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/core/feedback/presentation/feedback_host.dart';
import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/app_strings_delegate.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/observability/presentation/performance_overlay_host.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/global_stale_banner.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/order_update_listener.dart';

class StockPulseApp extends ConsumerWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final showPerformanceOverlay = ref.watch(debugOverlayProvider);
    return MaterialApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => context.strings.common.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      // Hosts sit above every route, so snackbars, outcomes, alert banners
      // and the stale banner show on any screen.
      builder: (context, child) => PerformanceOverlayHost(
        enabled: showPerformanceOverlay && !kReleaseMode,
        child: FeedbackHost(
          onOpenLocation: router.go,
          child: AppLifecycleHost(
            child: AlertBannerHost(
              child: GlobalStaleBanner(
                child: OrderUpdateListener(child: child!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:stock_pulse/core/visibility/application/covered_state_notifier.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

/// Tracks the opaque pages above the shell on the root navigator and
/// publishes [CoveredState]. Sheets, dialogs and other non-opaque routes are
/// ignored, so the stock page stays live under the order ticket.
///
/// The shell's own page ([kShellPageName]) is never a cover. A cold start on
/// a deep link has no shell page, so the linked screen counts as covering.
///
/// go_router changes its pages while the tree builds, and a provider may not
/// change then, so a change seen during a build is published after the frame.
class VisibilityRouteObserver extends NavigatorObserver {
  VisibilityRouteObserver(this._notifier);

  final CoveredStateNotifier _notifier;
  final _opaque = <(Route<dynamic>, ScreenId?)>[];
  bool _publishScheduled = false;

  static final _ids = ScreenId.values.asNameMap();

  static bool _covers(Route<dynamic> r) =>
      r is PageRoute && r.opaque && r.settings.name != kShellPageName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_covers(route)) return;
    _opaque.add((route, _ids[route.settings.name]));
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = _opaque.indexWhere((e) => e.$1 == oldRoute);
    if (i == -1) {
      if (newRoute != null) didPush(newRoute, null);
      return;
    }
    if (newRoute != null && _covers(newRoute)) {
      _opaque[i] = (newRoute, _ids[newRoute.settings.name]);
    } else {
      _opaque.removeAt(i);
    }
    _publish();
  }

  void _remove(Route<dynamic> route) {
    final before = _opaque.length;
    _opaque.removeWhere((e) => e.$1 == route);
    if (_opaque.length != before) _publish();
  }

  void _publish() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _publishNow();
      return;
    }
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _publishScheduled = false;
      _publishNow();
    });
  }

  void _publishNow() => _notifier.set(
    CoveredState(
      topOpaque: _opaque.isEmpty ? null : _opaque.last.$2,
      opaqueDepth: _opaque.length,
    ),
  );
}

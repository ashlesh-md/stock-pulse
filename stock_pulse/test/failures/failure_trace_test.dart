import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every failure row F1…F18 of the PRD maps to at least one named test:
/// the file, and a fragment of the test name that must still be in it.
const _trace = <String, List<(String, String)>>{
  'F1': [
    (
      'test/core/network/network_freshness_test.dart',
      'failed health probe reports offline while the socket reconnects',
    ),
    (
      'test/app/snapshot_restore_test.dart',
      'restore seeds quotes, instruments and an empty portfolio',
    ),
  ],
  'F2': [
    ('test/failures/network/socket_failures_test.dart', 'F2 '),
    ('test/failures/network/rest_failures_test.dart', 'F2 '),
  ],
  'F3': [('test/core/network/api_read_retry_test.dart', 'F3 ')],
  'F4': [
    ('test/core/network/api_read_retry_test.dart', 'F4 '),
    ('test/failures/network/rest_failures_test.dart', 'F4 '),
  ],
  'F5': [('test/failures/network/rest_failures_test.dart', 'F5 ')],
  'F6': [
    ('test/failures/network/socket_failures_test.dart', 'F6 '),
    ('test/failures/network/bad_payload_failures_test.dart', 'F6 '),
  ],
  'F7': [
    ('test/failures/network/socket_failures_test.dart', 'F7 '),
    (
      'test/features/server_restart_reconciliation_test.dart',
      'positions reconcile after 20 server listener restarts',
    ),
  ],
  'F8': [('test/failures/network/clock_skew_failures_test.dart', 'F8 ')],
  'F9': [
    ('test/features/alerts/alerts_screen_test.dart', 'empty screen opens form'),
    (
      'test/features/options/presentation/chain_screen_test.dart',
      'an expiry without strikes says so',
    ),
    (
      'test/features/chart/presentation/chart_edge_states_test.dart',
      'explains an empty history',
    ),
    (
      'test/features/portfolio/presentation/pnl_and_empty_test.dart',
      'offer Go to watchlist',
    ),
  ],
  'F10': [
    (
      'test/features/more/notifications_row_test.dart',
      'denied: a tap opens the system settings',
    ),
  ],
  'F11': [('test/failures/platform/storage_failures_test.dart', 'F11 ')],
  'F12': [
    (
      'test/features/orders/order_submit_reconciliation_test.dart',
      'a stored order with a dropped acknowledgement is reconciled once',
    ),
  ],
  'F13': [
    (
      'test/app/app_lifecycle_host_test.dart',
      'FR-85: hidden pauses the socket, shown resumes it',
    ),
  ],
  'F14': [
    ('test/app/router/app_router_test.dart', 'F14: '),
    ('test/failures/platform/push_analytics_failures_test.dart', 'F14 '),
  ],
  'F15': [('test/failures/platform/push_analytics_failures_test.dart', 'F15 ')],
  'F16': [('test/failures/platform/push_analytics_failures_test.dart', 'F16 ')],
  'F17': [
    ('test/failures/trading/confirm_failures_test.dart', 'F17 '),
    (
      'test/core/feedback/feedback_controller_test.dart',
      'FR-156: the same key five times shows one message',
    ),
  ],
  'F18': [
    (
      'test/core/l10n/l10n_test.dart',
      'every AppStrings area resolves a non-empty representative key',
    ),
    (
      'test/tool/ci/source_checks_test.dart',
      'asset check reports literal paths outside the image registry',
    ),
  ],
};

void main() {
  test('every failure row F1 to F18 maps to at least one named test', () {
    expect(_trace.keys, [for (var i = 1; i <= 18; i++) 'F$i']);
  });

  for (final MapEntry(key: row, value: links) in _trace.entries) {
    test('$row is traced to tests that still exist', () {
      for (final (path, name) in links) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$row: $path is missing');
        expect(
          file.readAsStringSync(),
          contains(name),
          reason: '$row: no test named like "$name" in $path',
        );
      }
    });
  }
}

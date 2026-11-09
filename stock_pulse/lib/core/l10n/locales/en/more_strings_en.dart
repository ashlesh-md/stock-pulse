import 'package:stock_pulse/core/l10n/strings/more_strings.dart';

final class MoreStringsEn implements MoreStrings {
  const MoreStringsEn();

  @override
  String get title => 'More';
  @override
  String get developer => 'Developer';
  @override
  String get debugClock => 'Demo clock';
  @override
  String get clockExplanation => 'Jump to a market-time preset (IST).';
  @override
  String get clockFailed =>
      'Could not update the demo. Check the connection and retry.';
  @override
  String get resetDemo => 'Reset demo account';
  @override
  String get backwardReset =>
      'Going back resets the demo account and removes saved preferences. Continue?';
  @override
  String get needsConnection => 'Needs connection';
  @override
  String get cancel => 'Cancel';

  @override
  String get addFunds => 'Add funds';
  @override
  String get amount => 'Amount (₹)';
  @override
  String amountInvalid(String max) => 'Enter an amount above zero, up to $max';
  @override
  String get quickAmounts => 'Quick amounts';
  @override
  String get paymentMethod => 'Pay with';
  @override
  String get simulatedPayment =>
      'Demo payment only. No real money is transferred.';
  @override
  String get upi => 'UPI';
  @override
  String get netBanking => 'Net banking';
  @override
  String get confirmFunds => 'Confirm demo payment';
  @override
  String get fundsFailed =>
      'Payment status could not be confirmed. Retry the same amount and method safely.';
  @override
  String fundsAdded(String available) =>
      'Funds added. Available balance $available';
  @override
  String get haptics => 'Order vibration feedback';
  @override
  String get analytics => 'Share anonymous usage events';
  @override
  String get debugOverlay => 'Show performance overlay';
  @override
  String get notifications => 'Price alert notifications';
  @override
  String get notificationsOff => 'Notifications off';
  @override
  String get notificationAlertExplanation =>
      'Get a notification when one of your price alerts is reached. You can keep using in-app alerts without enabling notifications.';
  @override
  String get enableNotifications => 'Enable notifications';
  @override
  String get notNow => 'Not now';

  @override
  String get socketLab => 'Socket Lab';
  @override
  String get pauseLog => 'Pause log';
  @override
  String get resumeLog => 'Resume log';
  @override
  String get clearLog => 'Clear';
  @override
  String get dropConnection => 'Drop connection';
  @override
  String get dropExplained =>
      'Server closes the socket (4002). Watch it reconnect.';
  @override
  String get freezeServer => 'Freeze server 15s';
  @override
  String get freezeExplained =>
      'Server goes silent 15s, socket stays "open". The heartbeat must notice.';
  @override
  String get skipSeq => 'Skip a seq';
  @override
  String get skipSeqExplained =>
      'Server skips a seq number. The app sees a gap and reloads over REST.';
  @override
  String get starting => 'Starting…';
  @override
  String connected(String sessionId, String roundTrip) =>
      'Connected as $sessionId. Ping round trip: $roundTrip';
  @override
  String reconnecting(String reason, int attempt, int delayMs) =>
      'Closed ($reason). Attempt $attempt in $delayMs ms '
      '(exponential backoff + jitter).';
  @override
  String connecting(int attempt) =>
      'Opening WebSocket (HTTP Upgrade → 101)… attempt $attempt';
  @override
  String get paused => 'Paused: app is in the background.';
  @override
  String traffic(int received, String chars, int sent) =>
      'In $received frames ($chars chars) · Out $sent frames';
}

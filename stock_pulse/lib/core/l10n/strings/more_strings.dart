/// The More tab and its developer screens.
abstract interface class MoreStrings {
  String get title;
  String get developer;
  String get debugClock;
  String get clockExplanation;
  String get clockFailed;
  String get resetDemo;
  String get backwardReset;
  String get needsConnection;
  String get cancel;

  String get addFunds;
  String get amount;
  String amountInvalid(String max);
  String get quickAmounts;
  String get paymentMethod;
  String get simulatedPayment;
  String get upi;
  String get netBanking;
  String get confirmFunds;
  String get fundsFailed;
  String fundsAdded(String available);
  String get haptics;
  String get analytics;
  String get debugOverlay;
  String get notifications;
  String get notificationsOff;
  String get notificationAlertExplanation;
  String get enableNotifications;
  String get notNow;

  String get socketLab;
  String get pauseLog;
  String get resumeLog;
  String get clearLog;
  String get dropConnection;
  String get dropExplained;
  String get freezeServer;
  String get freezeExplained;
  String get skipSeq;
  String get skipSeqExplained;
  String get starting;
  String connected(String sessionId, String roundTrip);
  String reconnecting(String reason, int attempt, int delayMs);
  String connecting(int attempt);
  String get paused;
  String traffic(int received, String chars, int sent);
}

import 'package:stock_pulse/core/l10n/locales/en/more_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/more_strings.dart';

final class MoreStringsPseudo implements MoreStrings {
  const MoreStringsPseudo();

  static const _en = MoreStringsEn();

  @override
  String get title => pseudo(_en.title);
  @override
  String get developer => pseudo(_en.developer);
  @override
  String get debugClock => pseudo(_en.debugClock);
  @override
  String get clockExplanation => pseudo(_en.clockExplanation);
  @override
  String get clockFailed => pseudo(_en.clockFailed);
  @override
  String get resetDemo => pseudo(_en.resetDemo);
  @override
  String get backwardReset => pseudo(_en.backwardReset);
  @override
  String get needsConnection => pseudo(_en.needsConnection);
  @override
  String get cancel => pseudo(_en.cancel);
  @override
  String get addFunds => pseudo(_en.addFunds);
  @override
  String get amount => pseudo(_en.amount);
  @override
  String amountInvalid(String max) => pseudo(_en.amountInvalid(max));
  @override
  String get quickAmounts => pseudo(_en.quickAmounts);
  @override
  String get paymentMethod => pseudo(_en.paymentMethod);
  @override
  String get simulatedPayment => pseudo(_en.simulatedPayment);
  @override
  String get upi => pseudo(_en.upi);
  @override
  String get netBanking => pseudo(_en.netBanking);
  @override
  String get confirmFunds => pseudo(_en.confirmFunds);
  @override
  String get fundsFailed => pseudo(_en.fundsFailed);
  @override
  String fundsAdded(String available) => pseudo(_en.fundsAdded(available));
  @override
  String get haptics => pseudo(_en.haptics);
  @override
  String get analytics => pseudo(_en.analytics);
  @override
  String get debugOverlay => pseudo(_en.debugOverlay);
  @override
  String get notifications => pseudo(_en.notifications);
  @override
  String get notificationsOff => pseudo(_en.notificationsOff);
  @override
  String get notificationAlertExplanation =>
      pseudo(_en.notificationAlertExplanation);
  @override
  String get enableNotifications => pseudo(_en.enableNotifications);
  @override
  String get notNow => pseudo(_en.notNow);
  @override
  String get socketLab => pseudo(_en.socketLab);
  @override
  String get pauseLog => pseudo(_en.pauseLog);
  @override
  String get resumeLog => pseudo(_en.resumeLog);
  @override
  String get clearLog => pseudo(_en.clearLog);
  @override
  String get dropConnection => pseudo(_en.dropConnection);
  @override
  String get dropExplained => pseudo(_en.dropExplained);
  @override
  String get freezeServer => pseudo(_en.freezeServer);
  @override
  String get freezeExplained => pseudo(_en.freezeExplained);
  @override
  String get skipSeq => pseudo(_en.skipSeq);
  @override
  String get skipSeqExplained => pseudo(_en.skipSeqExplained);
  @override
  String get starting => pseudo(_en.starting);
  @override
  String connected(String sessionId, String roundTrip) =>
      pseudo(_en.connected(sessionId, roundTrip));
  @override
  String reconnecting(String reason, int attempt, int delayMs) =>
      pseudo(_en.reconnecting(reason, attempt, delayMs));
  @override
  String connecting(int attempt) => pseudo(_en.connecting(attempt));
  @override
  String get paused => pseudo(_en.paused);
  @override
  String traffic(int received, String chars, int sent) =>
      pseudo(_en.traffic(received, chars, sent));
}

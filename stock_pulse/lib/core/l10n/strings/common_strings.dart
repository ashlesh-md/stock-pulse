/// Shared words and the texts of `core/widgets`.
abstract interface class CommonStrings {
  String get appTitle;
  String get retry;
  String get dismiss;
  String get loading;
  String get done;
  String get linkNotAvailable;

  /// Shown where a number is not known yet.
  String get noValue;

  String get connectionLive;
  String get connectionDelayed;
  String get connectionReconnecting;
  String get connectionOffline;
  String connectionSemantics(String state);

  String get phasePreOpen;
  String get phaseOpen;
  String get phaseClosed;
  String marketSemantics(String phase);
  String demoClock(String time);
  String demoClockSemantics(String time, String phase);

  String get stale;
  String staleSince(String time);
  String get pricesNotLive;
  String pricesNotLiveSince(String time);

  String get pending;
  String get orderPendingSemantics;

  String get changeUnavailable;
  String get unchanged;
  String changeUp(String amount, String percent);
  String changeDown(String amount, String percent);

  String get priceUnavailable;

  /// [direction] and [stale] are already-localised suffixes or empty.
  String priceSemantics(
    String amount, {
    required String direction,
    required bool stale,
  });
  String get priceUp;
  String get priceDown;

  String get lotsUnit;
  String lots(int n);
  String stepperValue(int n, String unit);
  String decrease(String unit);
  String increase(String unit);
}

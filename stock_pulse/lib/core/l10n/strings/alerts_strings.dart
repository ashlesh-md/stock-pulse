class AlertsStrings {
  const AlertsStrings();
  String get dismiss => 'Dismiss';
  String get view => 'View instrument';
  String conditionPrice(String condition, String price) => '$condition $price';
  String get title => 'Price alerts';
  String get triggeredAlert => 'Triggered price alert';
  String get empty => 'No price alerts. Create one to follow a price.';
  String get create => 'Create alert';
  String get symbol => 'Instrument';
  String get level => 'Alert price';
  String get condition => 'Condition';
  String get above => 'Above';
  String get below => 'Below';
  String get invalid =>
      'Enter an instrument and a finite price greater than zero';
  String get failed => 'Could not update the alert. Please retry.';
  String get cancel => 'Cancel alert';
  String triggered(String symbol, String price) => '$symbol reached $price';
}

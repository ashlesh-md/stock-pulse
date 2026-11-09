class OptionsStrings {
  const OptionsStrings();
  String get sectionTitle => 'Options';
  String get chooseUnderlying => 'Choose underlying';
  String get chooseUnderlyingHint =>
      'Choose an underlying to load its option chain. You can change it later.';
  String get chooseUnderlyingAction => 'Choose underlying';
  String title(String underlying) => '$underlying options';
  String get call => 'Call';
  String get put => 'Put';
  String get calls => 'CALLS';
  String get puts => 'PUTS';
  String get strikeHeader => 'STRIKE';
  String get oi => 'OI';
  String get oiChange => 'ΔOI';
  String get ltp => 'LTP';
  String get iv => 'IV';
  String get delta => 'Δ';
  String get greeks => 'Option Greeks';
  String get gamma => 'Gamma';
  String get theta => 'Theta / day';
  String get vega => 'Vega / vol point';
  String get greeksUnavailable => 'Greeks are unavailable for this contract.';
  String greekValue(String label, String value) => '$label $value';
  String get columns => 'Columns';
  String get alwaysShown => 'Always shown';
  String get atm => 'ATM';
  String get backToAtm => 'Back to ATM';
  String get addToStrategy => 'Add to strategy';
  String get strategyAdded => 'Added to strategy';
  String get viewStrategy => 'View';
  String get strategyFull => 'Up to 4 legs in preview';
  String get startNew => 'Start new';
  String strategyOtherChain(String chain) => 'Strategy uses $chain';
  String get weekly => 'Weekly';
  String get monthly => 'Monthly';
  String get expiresToday => 'Expires today';
  String get empty => 'No contracts available for this expiry';
  String expiredNotice(String oldExpiry, String newExpiry) =>
      '$oldExpiry expired · showing $newExpiry';
  String spot(String underlying, String price) => '$underlying $price';
  String cellSemantics(String side, int strike, String ltp, String oi) =>
      '$side $strike, LTP $ltp, OI $oi';
  String details(int oi, double? iv, double? delta) =>
      'OI $oi · IV ${iv?.toStringAsFixed(2) ?? '—'}% · Delta ${delta?.toStringAsFixed(2) ?? '—'}';
}

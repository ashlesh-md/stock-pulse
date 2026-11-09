/// One explainable term. Paragraphs are descriptive, never advice;
/// `**bold**` is the only markup.
class GlossaryEntry {
  const GlossaryEntry({
    required this.title,
    required this.paragraphs,
    this.related = const [],
    this.synonyms = const [],
  });

  final String title;
  final List<String> paragraphs;

  /// Other glossary keys ("Related: …" and the done chips).
  final List<String> related;

  /// Other ways a question names this term (lower case).
  final List<String> synonyms;
}

/// Keys are lower case, as the parser sees them.
const glossary = <String, GlossaryEntry>{
  'ltp': GlossaryEntry(
    title: 'LTP',
    paragraphs: [
      '**LTP** (last traded price) is the price of the most recent trade.',
      'It moves with every trade, so two screens can show slightly different values a moment apart.',
    ],
    related: ['premium', 'strike'],
    synonyms: ['last traded price', 'last price'],
  ),
  'iv': GlossaryEntry(
    title: 'Implied volatility',
    paragraphs: [
      '**Implied volatility (IV)** is the yearly move the option price implies for the underlying, as a percentage.',
      'Higher IV means a higher premium for the same strike and expiry. IV usually differs from strike to strike.',
    ],
    related: ['vega', 'premium'],
    synonyms: ['implied volatility', 'volatility'],
  ),
  'theta': GlossaryEntry(
    title: 'Theta',
    paragraphs: [
      '**Theta** is how much an option price changes as one day passes, with everything else unchanged.',
      'It is usually negative for a buyer: time value shrinks as expiry gets closer, faster in the last days.',
    ],
    related: ['vega', 'expiry'],
    synonyms: ['time decay'],
  ),
  'delta': GlossaryEntry(
    title: 'Delta',
    paragraphs: [
      '**Delta** is how much an option price moves for a ₹1 move in the underlying.',
      'Calls have delta between 0 and 1, puts between −1 and 0. An ATM option is near ±0.5.',
    ],
    related: ['gamma', 'atm'],
  ),
  'gamma': GlossaryEntry(
    title: 'Gamma',
    paragraphs: [
      '**Gamma** is how fast delta changes when the underlying moves.',
      'It is largest for ATM options close to expiry.',
    ],
    related: ['delta', 'atm'],
  ),
  'vega': GlossaryEntry(
    title: 'Vega',
    paragraphs: [
      '**Vega** is how much an option price changes for a 1 point change in implied volatility.',
    ],
    related: ['iv', 'theta'],
  ),
  'oi': GlossaryEntry(
    title: 'Open interest',
    paragraphs: [
      '**Open interest (OI)** is the number of contracts that are open and not yet closed or settled.',
      'A rising OI means new positions are being opened at that strike.',
    ],
    related: ['pcr', 'max pain'],
    synonyms: ['open interest'],
  ),
  'pcr': GlossaryEntry(
    title: 'Put-call ratio',
    paragraphs: [
      '**PCR** is total put open interest divided by total call open interest for one expiry.',
      'A PCR of 1 means as many puts as calls are open. It describes positioning; it does not predict a move.',
    ],
    related: ['oi', 'max pain'],
    synonyms: ['put call ratio', 'put-call ratio'],
  ),
  'max pain': GlossaryEntry(
    title: 'Max pain',
    paragraphs: [
      '**Max pain** is the strike at which all open options of one expiry would be worth the least in total at expiry.',
      'It is computed from open interest and changes as positions change.',
    ],
    related: ['oi', 'pcr'],
    synonyms: ['maxpain', 'max pain point'],
  ),
  'strike': GlossaryEntry(
    title: 'Strike price',
    paragraphs: [
      '**Strike** is the price at which an option lets its holder buy (call) or sell (put) the underlying.',
      'An option chain lists strikes at a fixed step around the current price.',
    ],
    related: ['atm', 'chain'],
    synonyms: ['strike price'],
  ),
  'expiry': GlossaryEntry(
    title: 'Expiry',
    paragraphs: [
      '**Expiry** is the day an option contract ends and is settled.',
      'NIFTY options here expire weekly on Tuesday; stock options expire on the last Tuesday of the month.',
    ],
    related: ['theta', 'strike'],
    synonyms: ['expiry date', 'expiration'],
  ),
  'premium': GlossaryEntry(
    title: 'Premium',
    paragraphs: [
      '**Premium** is the price of an option per unit. A buyer pays it; a seller receives it.',
      'The total paid is premium × lot size × lots.',
    ],
    related: ['lot size', 'iv'],
    synonyms: ['option premium', 'option price'],
  ),
  'lot size': GlossaryEntry(
    title: 'Lot size',
    paragraphs: [
      '**Lot size** is the number of units in one option contract. Orders are placed in whole lots.',
    ],
    related: ['premium', 'strike'],
    synonyms: ['lot', 'lots'],
  ),
  'atm': GlossaryEntry(
    title: 'At the money',
    paragraphs: [
      '**ATM** (at the money) is the strike closest to the current price of the underlying.',
    ],
    related: ['itm', 'otm'],
    synonyms: ['at the money'],
  ),
  'itm': GlossaryEntry(
    title: 'In the money',
    paragraphs: [
      '**ITM** (in the money): a call whose strike is below the price, or a put whose strike is above it.',
      'An ITM option has intrinsic value.',
    ],
    related: ['atm', 'otm'],
    synonyms: ['in the money'],
  ),
  'otm': GlossaryEntry(
    title: 'Out of the money',
    paragraphs: [
      '**OTM** (out of the money): a call whose strike is above the price, or a put whose strike is below it.',
      'An OTM option has only time value, which is zero at expiry.',
    ],
    related: ['atm', 'itm'],
    synonyms: ['out of the money'],
  ),
  'breakeven': GlossaryEntry(
    title: 'Breakeven',
    paragraphs: [
      '**Breakeven** is the underlying price at expiry where a position makes neither profit nor loss.',
      'A long call breaks even at strike + premium; a long put at strike − premium.',
    ],
    related: ['premium', 'straddle'],
    synonyms: ['break even', 'breakeven point', 'breakevens'],
  ),
  'straddle': GlossaryEntry(
    title: 'Straddle',
    paragraphs: [
      'A **straddle** is a call and a put at the same strike and expiry.',
      'A long straddle gains from a large move either way and loses at most the total premium.',
    ],
    related: ['strangle', 'breakeven'],
    synonyms: ['long straddle'],
  ),
  'strangle': GlossaryEntry(
    title: 'Strangle',
    paragraphs: [
      'A **strangle** is an OTM call and an OTM put on the same expiry.',
      'It costs less than a straddle and needs a larger move to reach breakeven.',
    ],
    related: ['straddle', 'otm'],
    synonyms: ['long strangle'],
  ),
  'iron condor': GlossaryEntry(
    title: 'Iron condor',
    paragraphs: [
      'An **iron condor** sells an OTM put and an OTM call and buys further OTM wings on both sides.',
      'Both the maximum profit and the maximum loss are limited.',
    ],
    related: ['strangle', 'breakeven'],
    synonyms: ['condor'],
  ),
  'chain': GlossaryEntry(
    title: 'Option chain',
    paragraphs: [
      'An **option chain** lists every call and put of one underlying and expiry, strike by strike.',
      'Each row shows price, open interest and IV for the call and the put at that strike.',
    ],
    related: ['oi', 'strike'],
    synonyms: ['option chain', 'options chain'],
  ),
};

/// The glossary key for [phrase] (a key or a synonym), or null.
String? lookupTerm(String phrase) {
  if (glossary.containsKey(phrase)) return phrase;
  for (final MapEntry(:key, :value) in glossary.entries) {
    if (value.synonyms.contains(phrase)) return key;
  }
  return null;
}

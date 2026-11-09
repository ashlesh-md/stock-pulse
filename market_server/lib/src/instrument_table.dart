import 'package:market_server/src/models.dart';

/// The NIFTY index and its 50 constituents. Names are real NSE companies so
/// the app feels familiar; every price is simulated and has nothing to do
/// with the real market. [Instrument.weight] is the index weight (%): NIFTY
/// moves by the weighted constituent moves, from its base at seed.
final instruments = <Instrument>[
  const Instrument(
    symbol: 'NIFTY',
    name: 'Nifty 50',
    exchange: 'NSE',
    sector: 'Index',
    basePrice: 24600.00,
    kind: InstrumentKind.marketIndex,
    bandPct: null,
    strikeStep: 50,
  ),
  for (final (symbol, name, sector, basePrice, weight) in _constituents)
    Instrument(
      symbol: symbol,
      name: name,
      exchange: 'NSE',
      sector: sector,
      basePrice: basePrice,
      weight: weight,
      strikeStep: _strikeSteps[symbol],
    ),
];

/// Equities with an option chain.
const _strikeSteps = <String, int>{'RELIANCE': 10, 'HDFCBANK': 10};

const _constituents = <(String, String, String, double, double)>[
  ('RELIANCE', 'Reliance Industries', 'Energy', 1412.35, 8.5),
  ('HDFCBANK', 'HDFC Bank', 'Banking', 1001.45, 13.0),
  ('TCS', 'Tata Consultancy Services', 'IT', 3058.90, 3.0),
  ('INFY', 'Infosys', 'IT', 1487.20, 4.8),
  ('ICICIBANK', 'ICICI Bank', 'Banking', 1356.60, 8.6),
  ('SBIN', 'State Bank of India', 'Banking', 871.15, 3.0),
  ('ITC', 'ITC', 'FMCG', 409.80, 3.5),
  ('LT', 'Larsen & Toubro', 'Infra', 3921.05, 3.8),
  ('BHARTIARTL', 'Bharti Airtel', 'Telecom', 2034.55, 4.6),
  ('TATASTEEL', 'Tata Steel', 'Metals', 171.25, 1.2),
  ('ASIANPAINT', 'Asian Paints', 'Consumer', 2482.70, 0.9),
  ('MARUTI', 'Maruti Suzuki', 'Auto', 16210.00, 1.8),
  ('AXISBANK', 'Axis Bank', 'Banking', 1178.40, 3.0),
  ('KOTAKBANK', 'Kotak Mahindra Bank', 'Banking', 2094.85, 2.7),
  ('HINDUNILVR', 'Hindustan Unilever', 'FMCG', 2468.30, 1.9),
  ('BAJFINANCE', 'Bajaj Finance', 'Financial Services', 1004.60, 2.3),
  ('SUNPHARMA', 'Sun Pharmaceutical', 'Pharma', 1689.15, 1.6),
  ('HCLTECH', 'HCL Technologies', 'IT', 1512.75, 1.5),
  ('NTPC', 'NTPC', 'Power', 338.90, 1.4),
  ('TITAN', 'Titan Company', 'Consumer', 3612.40, 1.3),
  ('ULTRACEMCO', 'UltraTech Cement', 'Cement', 12045.00, 1.2),
  ('TATAMOTORS', 'Tata Motors', 'Auto', 682.35, 1.4),
  ('POWERGRID', 'Power Grid Corporation', 'Power', 289.65, 1.1),
  ('BAJAJFINSV', 'Bajaj Finserv', 'Financial Services', 2015.20, 0.9),
  ('ADANIPORTS', 'Adani Ports and SEZ', 'Infra', 1442.55, 0.9),
  ('ONGC', 'Oil and Natural Gas Corporation', 'Energy', 243.80, 0.8),
  ('COALINDIA', 'Coal India', 'Mining', 386.45, 0.8),
  ('NESTLEIND', 'Nestle India', 'FMCG', 1218.70, 0.7),
  ('WIPRO', 'Wipro', 'IT', 247.35, 0.7),
  ('JSWSTEEL', 'JSW Steel', 'Metals', 1146.90, 0.9),
  ('GRASIM', 'Grasim Industries', 'Cement', 2834.10, 0.9),
  ('TECHM', 'Tech Mahindra', 'IT', 1468.25, 0.8),
  ('HINDALCO', 'Hindalco Industries', 'Metals', 782.60, 0.9),
  ('ADANIENT', 'Adani Enterprises', 'Conglomerate', 2398.45, 0.6),
  ('CIPLA', 'Cipla', 'Pharma', 1521.30, 0.7),
  ('SBILIFE', 'SBI Life Insurance', 'Insurance', 1874.55, 0.7),
  ('DRREDDY', 'Dr. Reddy\'s Laboratories', 'Pharma', 1247.80, 0.6),
  ('EICHERMOT', 'Eicher Motors', 'Auto', 6941.25, 0.6),
  ('HDFCLIFE', 'HDFC Life Insurance', 'Insurance', 758.40, 0.7),
  ('BRITANNIA', 'Britannia Industries', 'FMCG', 5862.15, 0.5),
  ('APOLLOHOSP', 'Apollo Hospitals', 'Healthcare', 7489.60, 0.6),
  ('TATACONSUM', 'Tata Consumer Products', 'FMCG', 1132.85, 0.6),
  ('HEROMOTOCO', 'Hero MotoCorp', 'Auto', 5478.30, 0.5),
  ('INDUSINDBK', 'IndusInd Bank', 'Banking', 784.95, 0.4),
  ('SHRIRAMFIN', 'Shriram Finance', 'Financial Services', 668.20, 0.8),
  ('BEL', 'Bharat Electronics', 'Defence', 412.35, 1.2),
  ('TRENT', 'Trent', 'Retail', 4812.50, 0.8),
  ('ETERNAL', 'Eternal', 'Consumer Tech', 318.75, 1.6),
  ('DIVISLAB', 'Divi\'s Laboratories', 'Pharma', 6512.40, 0.5),
  ('BPCL', 'Bharat Petroleum', 'Energy', 341.60, 0.5),
];

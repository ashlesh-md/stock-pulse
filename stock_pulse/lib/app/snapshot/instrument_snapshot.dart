import 'package:stock_pulse/features/market/domain/instrument.dart';

Map<String, Object?> instrumentSnapshot(Instrument i) => {
  'id': i.id,
  'name': i.name,
  'exchange': i.exchange,
  'sector': i.sector,
  'tickSize': i.tickSize,
  'lotSize': i.lotSize,
  'kind': i.kind.wire,
  'bandLow': ?i.bandLow,
  'bandHigh': ?i.bandHigh,
  'strikeStep': ?i.strikeStep,
  'underlying': ?i.underlying,
  'expiry': ?i.expiry,
  'strike': ?i.strike,
  'right': ?i.right?.name,
};

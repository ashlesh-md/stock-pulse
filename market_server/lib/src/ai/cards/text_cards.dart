import 'package:market_server/src/ai/cards/card_envelope.dart';

/// Text arrives as deltas, so `body.paragraphs` starts empty.
Map<String, Object?> textCard({
  required String id,
  required String title,
  required DateTime asOf,
  required String fallbackText,
  List<String> terms = const [],
}) => cardEnvelope(
  id: id,
  type: 'text',
  title: title,
  asOf: asOf,
  instruments: const [],
  fallbackText: fallbackText,
  actions: const [],
  body: {'paragraphs': const <String>[], 'terms': terms},
);
Map<String, Object?> fallbackCard({
  required String id,
  required String message,
  required List<String> chips,
  required DateTime asOf,
}) => cardEnvelope(
  id: id,
  type: 'fallback',
  title: 'Try one of these',
  asOf: asOf,
  instruments: const [],
  fallbackText: message,
  actions: const [],
  body: {'message': message, 'chips': chips},
);

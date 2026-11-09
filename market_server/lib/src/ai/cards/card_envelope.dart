/// Card schema version. Clients show `fallbackText` for a
/// higher version.
const cardVersion = 1;

const _maxFallbackChars = 300;

Map<String, Object?> action(
  String kind,
  String label,
  Map<String, Object?> args,
) => {'kind': kind, 'label': label, 'args': args};

Map<String, Object?> cardEnvelope({
  required String id,
  required String type,
  required String title,
  required DateTime? asOf,
  required List<String> instruments,
  required String fallbackText,
  required List<Map<String, Object?>> actions,
  required Map<String, Object?> body,
}) {
  final fb = fallbackText.replaceAll('**', '');
  return {
    'id': id,
    'type': type,
    'v': cardVersion,
    'title': title,
    'asOf': asOf?.millisecondsSinceEpoch,
    'instruments': instruments,
    'fallbackText': fb.length <= _maxFallbackChars
        ? fb
        : '${fb.substring(0, _maxFallbackChars - 1)}…',
    'actions': actions,
    'body': body,
  };
}

/// Text card. The paragraphs travel as `delta` events, so the card itself

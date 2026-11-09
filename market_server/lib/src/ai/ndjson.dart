import 'dart:convert';

/// One JSON object per `\n`-terminated UTF-8 line, encoded as each event
/// arrives (no buffering here; `ai_api` turns shelf's buffering off).
Stream<List<int>> encodeNdjson(Stream<Map<String, Object?>> events) =>
    events.map((e) => utf8.encode('${jsonEncode(e)}\n'));

import 'package:flutter/foundation.dart';

@immutable
class AiCard {
  AiCard({
    required this.id,
    required this.type,
    required this.title,
    required this.fallbackText,
    Map<String, Object?> body = const {},
    this.asOf,
    List<String> instruments = const [],
    List<AiAction> actions = const [],
  }) : body = Map.unmodifiable(body),
       instruments = List.unmodifiable(instruments),
       actions = List.unmodifiable(actions);

  factory AiCard.fromJson(Map<String, Object?> json) {
    const supported = {
      'text',
      'quote',
      'chart',
      'chain',
      'payoff',
      'table',
      'fallback',
    };
    final type = json['type'] as String? ?? 'unknown';
    return AiCard(
      id: json['id'] as String? ?? 'unknown',
      type: json['v'] == 1 && supported.contains(type) ? type : 'unknown',
      title: json['title'] as String? ?? '',
      fallbackText: json['fallbackText'] as String? ?? '',
      body: json['body'] as Map<String, Object?>? ?? const {},
      asOf: switch (json['asOf']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        _ => null,
      },
      instruments: (json['instruments'] as List<Object?>? ?? const [])
          .cast<String>(),
      actions: [
        for (final action in json['actions'] as List<Object?>? ?? const [])
          if (AiAction.fromJson(action! as Map<String, Object?>)
              case final AiAction value)
            value,
      ],
    );
  }

  final String id;
  final String type;
  final String title;
  final String fallbackText;
  final Map<String, Object?> body;
  final DateTime? asOf;
  final List<String> instruments;
  final List<AiAction> actions;

  String get text => switch (body['paragraphs']) {
    final List<Object?> paragraphs => paragraphs.join('\n\n'),
    _ => fallbackText,
  };

  AiCard append(String text) => AiCard(
    id: id,
    type: type,
    title: title,
    fallbackText: fallbackText,
    body: {
      ...body,
      'paragraphs': ['${this.text}$text'],
    },
    asOf: asOf,
    instruments: instruments,
    actions: actions,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'v': 1,
    'title': title,
    'fallbackText': fallbackText,
    'body': body,
    'asOf': asOf?.millisecondsSinceEpoch,
    'instruments': instruments,
    'actions': actions.map((a) => a.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is AiCard &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.fallbackText == fallbackText &&
      mapEquals(other.body, body) &&
      other.asOf == asOf &&
      listEquals(other.instruments, instruments) &&
      listEquals(other.actions, actions);
  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    fallbackText,
    Object.hashAll(body.entries.map((e) => Object.hash(e.key, e.value))),
    asOf,
    Object.hashAll(instruments),
    Object.hashAll(actions),
  );
}

@immutable
class AiAction {
  AiAction(this.kind, this.label, Map<String, Object?> args)
    : args = Map.unmodifiable(args);
  static const supported = {
    'open_stock',
    'open_chart',
    'set_alert',
    'open_chain',
    'trade',
    'view_payoff',
    'explain',
  };
  static AiAction? fromJson(Map<String, Object?> json) =>
      supported.contains(json['kind'])
      ? AiAction(
          json['kind']! as String,
          json['label']! as String,
          json['args'] as Map<String, Object?>? ?? const {},
        )
      : null;
  final String kind;
  final String label;
  final Map<String, Object?> args;
  Map<String, Object?> toJson() => {'kind': kind, 'label': label, 'args': args};
  @override
  bool operator ==(Object other) =>
      other is AiAction &&
      kind == other.kind &&
      label == other.label &&
      mapEquals(args, other.args);
  @override
  int get hashCode => Object.hash(
    kind,
    label,
    Object.hashAll(args.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

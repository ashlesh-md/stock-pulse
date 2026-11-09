import 'package:flutter/foundation.dart';

/// What the conversation is about, sent back with the next question so a
/// follow-up like "and the chain?" resolves to the same underlying.
@immutable
class AskTopic {
  const AskTopic({this.underlying, this.expiry});

  factory AskTopic.fromJson(Map<String, Object?> json) => AskTopic(
    underlying: json['underlying'] as String?,
    expiry: json['expiry'] as String?,
  );

  final String? underlying;
  final String? expiry;

  Map<String, Object?> toJson() => {
    'underlying': ?underlying,
    'expiry': ?expiry,
  };

  @override
  bool operator ==(Object other) =>
      other is AskTopic &&
      other.underlying == underlying &&
      other.expiry == expiry;

  @override
  int get hashCode => Object.hash(underlying, expiry);
}

/// The topic a follow-up question inherits ("chain" after a NIFTY answer).
class AskContext {
  const AskContext({this.underlying, this.expiry});

  /// Throws [FormatException] unless [json] is a map of optional strings.
  factory AskContext.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('context must be an object');
    final underlying = json['underlying'];
    final expiry = json['expiry'];
    if (underlying != null && underlying is! String ||
        expiry != null && expiry is! String) {
      throw const FormatException('context fields must be strings');
    }
    return AskContext(
      underlying: underlying as String?,
      expiry: expiry as String?,
    );
  }

  final String? underlying;
  final String? expiry;

  Map<String, Object?> toJson() => {
    if (underlying != null) 'underlying': underlying,
    if (expiry != null) 'expiry': expiry,
  };

  AskContext copyWith({String? underlying, String? expiry}) => AskContext(
    underlying: underlying ?? this.underlying,
    expiry: expiry ?? this.expiry,
  );

  @override
  bool operator ==(Object other) =>
      other is AskContext &&
      other.underlying == underlying &&
      other.expiry == expiry;

  @override
  int get hashCode => Object.hash(underlying, expiry);

  @override
  String toString() => 'AskContext($underlying, $expiry)';
}

/// Body of `POST /api/v1/ai/ask`.
class AskRequest {
  const AskRequest({
    required this.question,
    required this.requestId,
    this.context,
  });

  /// Validates the body: question is a trimmed string of 1–200 chars,
  /// requestId 1–64 chars. Throws [FormatException] with a user-facing
  /// message otherwise (mapped to `400 invalid_question`).
  factory AskRequest.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Body must be a JSON object');
    final question = json['question'];
    if (question is! String ||
        question.trim().isEmpty ||
        question.trim().length > 200) {
      throw const FormatException('question must be 1–200 characters');
    }
    final requestId = json['requestId'];
    if (requestId is! String || requestId.isEmpty || requestId.length > 64) {
      throw const FormatException('requestId must be 1–64 characters');
    }
    final ctx = json['context'];
    return AskRequest(
      question: question.trim(),
      requestId: requestId,
      context: ctx == null ? null : AskContext.fromJson(ctx),
    );
  }

  final String question;
  final String requestId;
  final AskContext? context;
}

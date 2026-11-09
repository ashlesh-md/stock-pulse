import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/cards/text_cards.dart';

/// One card plus the text that streams into it as `delta` events.
class CardDraft {
  const CardDraft(this.card, [this.textChunks = const []]);

  final Map<String, Object?> card;
  final List<String> textChunks;
}

/// Everything one answer sends: ≤ 4 cards, the follow-up topic and chips.
class AnswerPlan {
  const AnswerPlan({
    required this.cards,
    required this.topic,
    required this.chips,
  });

  final List<CardDraft> cards;
  final AskContext topic;
  final List<String> chips;
}

/// Collects cards with ids `<answerId>.c<n>` and splits text into chunks.
class PlanBuilder {
  PlanBuilder(this.answerId, this.now);

  final String answerId;
  final DateTime now;
  final _cards = <CardDraft>[];

  String nextId() => '$answerId.c${_cards.length + 1}';

  void card(Map<String, Object?> card) => _cards.add(CardDraft(card));

  /// A text card whose paragraphs stream as 4-word deltas; `\n\n` opens a
  /// new paragraph.
  void text(
    String title,
    List<String> paragraphs, {
    List<String> terms = const [],
  }) {
    final chunks = <String>[];
    for (var p = 0; p < paragraphs.length; p++) {
      final words = paragraphs[p].split(' ');
      for (var i = 0; i < words.length; i += 4) {
        final piece = words
            .sublist(i, (i + 4).clamp(0, words.length))
            .join(' ');
        chunks.add(i == 0 ? (p == 0 ? piece : '\n\n$piece') : ' $piece');
      }
    }
    _cards.add(
      CardDraft(
        textCard(
          id: nextId(),
          title: title,
          asOf: now,
          fallbackText: paragraphs.join(' '),
          terms: terms,
        ),
        List.unmodifiable(chunks),
      ),
    );
  }

  AnswerPlan plan(AskContext topic, List<String> chips) => AnswerPlan(
    cards: List.unmodifiable(_cards),
    topic: topic,
    chips: List.unmodifiable(chips),
  );
}

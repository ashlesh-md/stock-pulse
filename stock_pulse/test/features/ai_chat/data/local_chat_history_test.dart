import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_pulse/features/ai_chat/data/local_chat_history.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';

import '../chat_fakes.dart';

class _Prefs implements SharedPreferencesAsync {
  final values = <String, String>{};
  final _reads = [0];
  int get reads => _reads.single;
  @override
  Future<String?> getString(String key) async {
    _reads[0]++;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Prefs prefs;
  setUp(() => prefs = _Prefs());

  List<String> stored() => [
    for (final a in jsonDecode(prefs.values[LocalChatHistory.key]!) as List)
      (a as Map<String, Object?>)['id']! as String,
  ];

  test('pages newest first and keeps the full history on the device', () async {
    final history = LocalChatHistory(preferences: prefs);
    for (var i = 0; i < 25; i++) {
      await history.save(storedAnswer(i));
    }
    final first = await history.read(limit: 20);
    expect(first.answers.first.id, 'a5');
    expect(first.hasMore, isTrue);
    final older = await history.read(beforeId: 'a5', limit: 20);
    expect(older.answers.map((a) => a.id), ['a0', 'a1', 'a2', 'a3', 'a4']);
    expect(older.hasMore, isFalse);
    expect((await history.read(beforeId: 'a0', limit: 20)).answers, isEmpty);
    expect((await history.read(beforeId: 'gone', limit: 20)).answers, isEmpty);

    final reopened = LocalChatHistory(preferences: prefs);
    expect((await reopened.read(limit: 50)).answers, hasLength(25));
  });

  test('save replaces an answer with the same id', () async {
    final history = LocalChatHistory(preferences: prefs);
    final sending = ChatAnswer(
      id: 'x',
      question: 'Q',
      createdAt: DateTime.utc(2026),
    );
    await history.save(sending);
    await history.save(sending.copyWith(status: AnswerStatus.complete));
    final page = await history.read(limit: 5);
    expect(page.answers.single.status, AnswerStatus.complete);
    expect(prefs.reads, 1, reason: 'decoded once, then served from memory');
  });

  test('the oldest answers are dropped past the size cap', () async {
    final history = LocalChatHistory(preferences: prefs, maxChars: 400);
    for (var i = 0; i < 6; i++) {
      await history.save(storedAnswer(i));
    }
    expect(stored().last, 'a5');
    expect(stored().length, lessThan(6));
    expect(prefs.values[LocalChatHistory.key]!.length, lessThanOrEqualTo(400));
    final page = await history.read(limit: 10);
    expect(page.answers.map((a) => a.id), stored());
  });

  test('history retains only the newest 50 answers', () async {
    final history = LocalChatHistory(preferences: prefs, maxChars: 100000);
    for (var i = 0; i <= ChatLimits.maxAnswers; i++) {
      await history.save(storedAnswer(i));
    }

    final page = await history.read(limit: ChatLimits.maxAnswers);
    expect(page.answers, hasLength(ChatLimits.maxAnswers));
    expect(page.answers.first.id, 'a1');
    expect(page.answers.last.id, 'a50');
    expect(page.hasMore, isFalse);
  });

  test('clear empties memory and the stored list', () async {
    final history = LocalChatHistory(preferences: prefs);
    await history.save(storedAnswer(1));
    await history.clear();
    expect((await history.read(limit: 5)).answers, isEmpty);
    expect(prefs.values[LocalChatHistory.key], '[]');
  });

  test('unreadable stored text reads as an empty history', () async {
    for (final bad in [
      'not json',
      '{"a":1}',
      '[{"id":1}]',
      '[{"id":"x","question":"q","createdAt":9223372036854775807}]',
    ]) {
      prefs.values[LocalChatHistory.key] = bad;
      expect(
        (await LocalChatHistory(preferences: prefs).read(limit: 5)).answers,
        isEmpty,
      );
    }
    expect(
      (await LocalChatHistory(preferences: _Prefs()).read(limit: 5)).answers,
      isEmpty,
    );
  });
}

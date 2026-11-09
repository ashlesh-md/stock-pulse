import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_history.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';

/// The whole history as one JSON list, oldest first, decoded once and kept
/// in memory; pages are slices of it.
class LocalChatHistory implements ChatHistory {
  LocalChatHistory({
    SharedPreferencesAsync? preferences,
    this.maxChars = ChatLimits.maxHistoryChars,
  }) : _given = preferences;
  final SharedPreferencesAsync? _given;

  /// Created on first use, so building the provider needs no platform.
  late final SharedPreferencesAsync preferences =
      _given ?? SharedPreferencesAsync();
  final int maxChars;
  static const key = 'stockpulse.chat.v1';
  Future<List<ChatAnswer>>? _all;
  Future<void> _writes = Future.value();

  Future<List<ChatAnswer>> _load() =>
      _all ??= preferences.getString(key).then(_decode);

  static List<ChatAnswer> _decode(String? text) {
    if (text == null) return [];
    try {
      return [
        for (final item in jsonDecode(text) as List)
          ChatAnswer.fromJson(item as Map<String, Object?>),
      ];
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    } on ArgumentError {
      return [];
    }
  }

  @override
  Future<ChatPage> read({String? beforeId, required int limit}) async {
    final all = await _load();
    final end = beforeId == null
        ? all.length
        : all.indexWhere((a) => a.id == beforeId);
    if (end <= 0) return (answers: <ChatAnswer>[], hasMore: false);
    final start = (end - limit).clamp(0, end);
    return (answers: all.sublist(start, end), hasMore: start > 0);
  }

  @override
  Future<void> save(ChatAnswer answer) async {
    final all = await _load();
    final index = all.indexWhere((a) => a.id == answer.id);
    if (index < 0) {
      all.add(answer);
    } else {
      all[index] = answer;
    }
    if (all.length > ChatLimits.maxAnswers) {
      all.removeRange(0, all.length - ChatLimits.maxAnswers);
    }
    final json = [for (final a in all) jsonEncode(a.toJson())];
    var chars = json.fold(0, (sum, item) => sum + item.length + 1);
    var drop = 0;
    while (chars > maxChars && drop < all.length - 1) {
      chars -= json[drop++].length + 1;
    }
    all.removeRange(0, drop);
    return _write('[${json.skip(drop).join(',')}]');
  }

  @override
  Future<void> clear() {
    _all = Future.value([]);
    return _write('[]');
  }

  Future<void> _write(String text) => _writes = _writes
      .onError((Object _, StackTrace _) {})
      .then((_) => preferences.setString(key, text));
}

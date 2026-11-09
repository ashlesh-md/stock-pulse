import 'package:flutter/foundation.dart';

enum PushMessageType { alert, order, system }

@immutable
class PushMessage {
  const PushMessage({
    required this.id,
    this.title,
    this.body,
    this.link,
    this.type = PushMessageType.system,
    this.data = const {},
  });
  final String id;
  final String? title;
  final String? body;
  final Uri? link;
  final PushMessageType type;
  final Map<String, String> data;
}

abstract interface class PushService {
  Future<void> init();
  Future<String?> token();
  Future<PushMessage?> initialMessage();
  Stream<PushMessage> get onTap;
  Stream<PushMessage> get onForeground;
}

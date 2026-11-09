import 'package:flutter/foundation.dart';

@immutable
class ChatAttachment {
  const ChatAttachment({required this.name, required this.size, this.bytes});
  final String name;
  final int size;

  /// Kept in memory for the image preview only; history stores name and size.
  final Uint8List? bytes;
  bool get isImage => RegExp(
    r'\.(png|jpg|jpeg|gif|webp)$',
    caseSensitive: false,
  ).hasMatch(name);
  Map<String, Object?> toJson() => {'name': name, 'size': size};
  factory ChatAttachment.fromJson(Map<String, Object?> json) =>
      ChatAttachment(name: json['name']! as String, size: json['size']! as int);
  @override
  bool operator ==(Object other) =>
      other is ChatAttachment && name == other.name && size == other.size;
  @override
  int get hashCode => Object.hash(name, size);
}

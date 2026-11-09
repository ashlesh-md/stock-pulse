import 'package:flutter/foundation.dart';

@immutable
final class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.params = const {}]);
  final String name;
  final Map<String, Object> params;
  bool get isValid =>
      RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(name) &&
      params.length <= 25 &&
      params.entries.every(
        (e) =>
            !{
              'prompt',
              'email',
              'token',
              'account_id',
              'message',
              'text',
              'prompt_text',
              'amount',
              'price',
            }.contains(e.key) &&
            RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(e.key) &&
            (e.value is String &&
                    RegExp(r'^[A-Za-z0-9_/:.-]{1,64}$')
                        .hasMatch(e.value as String) ||
                e.value is int ||
                e.value is bool ||
                e.value is double && (e.value as double).isFinite),
      );
  @override
  bool operator ==(Object other) =>
      other is AnalyticsEvent &&
      other.name == name &&
      mapEquals(other.params, params);
  @override
  int get hashCode => Object.hash(
    name,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

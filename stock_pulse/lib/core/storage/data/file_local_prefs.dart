import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

/// `prefs.json` schema v1. Construction does no IO; [load] reads once, on
/// the first `localPrefsProvider` read.
///
/// `analyticsConsent` and `localeOverride` were added to v1 as optional
/// keys, so a file written before them still loads (risk acknowledgement
/// kept) with their defaults.
class FileLocalPrefs implements LocalPrefs {
  FileLocalPrefs(this._file, this._reporter);

  static const fileName = 'prefs.json';
  static const schemaVersion = 1;

  final AtomicJsonFile _file;
  final CrashReporter _reporter;
  LocalPrefsData _data = LocalPrefsData.defaults;

  @override
  LocalPrefsData get data => _data;

  /// Missing file → defaults, no log. Bad JSON or another schema → defaults
  /// and one `prefs_discarded`; the file is rewritten on the next [update].
  Future<LocalPrefs> load() async {
    String? text;
    try {
      text = await _file.readString();
      if (text == null) return this;
      _data = _decode(jsonDecode(text));
    } on Object catch (e) {
      _data = LocalPrefsData.defaults;
      _reporter.log('prefs_discarded', {
        'reason': e is FormatException ? 'corrupt' : 'bad_field',
        'bytes': text?.length ?? 0,
      });
    }
    return this;
  }

  static LocalPrefsData _decode(Object? j) {
    if (j is! Map<String, Object?>) {
      throw const FormatException('not an object');
    }
    if (j['schemaVersion'] != schemaVersion) {
      throw FormatException('schemaVersion ${j['schemaVersion']}');
    }
    final locale = j['localeOverride'] as String?;
    return LocalPrefsData(
      favouriteIds: Set.unmodifiable(
        (j['favouriteIds'] as List? ?? const []).cast<String>(),
      ),
      watchlistOrder: List.unmodifiable(
        (j['watchlistOrder'] as List? ?? const []).cast<String>(),
      ),
      pendingOrderRecords: List.unmodifiable(
        (j['pendingOrderRecords'] as List? ?? const []).cast<String>(),
      ),
      riskNoticeAcked: j['riskNoticeAcked']! as bool,
      hapticsEnabled: j['hapticsEnabled']! as bool,
      analyticsConsent:
          j['analyticsConsent'] as bool? ??
          LocalPrefsData.defaults.analyticsConsent,
      notificationExplainerShown:
          j['notificationExplainerShown'] as bool? ?? false,
      seenAlertIds: LinkedHashSet.of(
        (j['seenAlertIds']! as List).cast<String>(),
      ),
      lastChainUnderlying: j['lastChainUnderlying'] as String?,
      localeOverride: locale == null ? null : _localeFromTag(locale),
    );
  }

  /// `en` or `en-IN`; anything else is a bad field.
  static Locale _localeFromTag(String tag) {
    final parts = tag.split('-');
    if (parts.length > 2 || parts.any((p) => p.isEmpty)) {
      throw FormatException('localeOverride $tag');
    }
    return Locale(parts[0], parts.length == 2 ? parts[1] : null);
  }

  @override
  Future<void> update(LocalPrefsData Function(LocalPrefsData current) change) {
    var next = change(_data);
    final seen = next.seenAlertIds;
    if (seen.length > LocalPrefsData.maxSeenAlertIds) {
      next = next.copyWith(
        seenAlertIds: LinkedHashSet.of(
          seen.skip(seen.length - LocalPrefsData.maxSeenAlertIds),
        ),
      );
    }
    _data = next;
    return _file.write({
      'schemaVersion': schemaVersion,
      'favouriteIds': next.favouriteIds.toList(),
      'watchlistOrder': next.watchlistOrder,
      'pendingOrderRecords': next.pendingOrderRecords,
      'riskNoticeAcked': next.riskNoticeAcked,
      'hapticsEnabled': next.hapticsEnabled,
      'analyticsConsent': next.analyticsConsent,
      'notificationExplainerShown': next.notificationExplainerShown,
      'seenAlertIds': next.seenAlertIds.toList(),
      'lastChainUnderlying': next.lastChainUnderlying,
      'localeOverride': next.localeOverride?.toLanguageTag(),
    });
  }

  @override
  Future<void> clear() {
    _data = LocalPrefsData.defaults;
    return _file.delete();
  }
}

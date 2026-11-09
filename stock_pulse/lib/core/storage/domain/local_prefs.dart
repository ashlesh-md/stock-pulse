import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

/// Small user settings kept across launches in `prefs.json`.
/// No age rule: a stale snapshot never resets the risk acknowledgement.
@immutable
class LocalPrefsData {
  const LocalPrefsData({
    required this.riskNoticeAcked,
    required this.hapticsEnabled,
    required this.analyticsConsent,
    this.notificationExplainerShown = false,
    required this.seenAlertIds,
    required this.lastChainUnderlying,
    required this.localeOverride,
    this.favouriteIds = const {},
    this.watchlistOrder = const [],
    this.pendingOrderRecords = const [],
  });

  static const defaults = LocalPrefsData(
    riskNoticeAcked: false,
    hapticsEnabled: true,
    analyticsConsent: !kReleaseMode,
    seenAlertIds: {},
    lastChainUnderlying: null,
    localeOverride: null,
  );

  /// Capped at this many ids, oldest dropped first (insertion order).
  static const maxSeenAlertIds = 500;

  final Set<String> favouriteIds;
  final List<String> watchlistOrder;
  final List<String> pendingOrderRecords;

  final bool riskNoticeAcked;
  final bool hapticsEnabled;

  /// Off → no analytics sink receives events.
  final bool analyticsConsent;

  /// True after the first-alert notification explanation was shown or skipped.
  final bool notificationExplainerShown;
  final Set<String> seenAlertIds;
  final String? lastChainUnderlying;

  /// Null follows the device locale.
  final Locale? localeOverride;

  LocalPrefsData copyWith({
    Set<String>? favouriteIds,
    List<String>? watchlistOrder,
    List<String>? pendingOrderRecords,
    bool? riskNoticeAcked,
    bool? hapticsEnabled,
    bool? analyticsConsent,
    bool? notificationExplainerShown,
    Set<String>? seenAlertIds,
    String? lastChainUnderlying,
    bool clearLastChainUnderlying = false,
    Locale? localeOverride,
    bool clearLocaleOverride = false,
  }) => LocalPrefsData(
    favouriteIds: favouriteIds ?? this.favouriteIds,
    watchlistOrder: watchlistOrder ?? this.watchlistOrder,
    pendingOrderRecords: pendingOrderRecords ?? this.pendingOrderRecords,
    riskNoticeAcked: riskNoticeAcked ?? this.riskNoticeAcked,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    analyticsConsent: analyticsConsent ?? this.analyticsConsent,
    notificationExplainerShown:
        notificationExplainerShown ?? this.notificationExplainerShown,
    seenAlertIds: seenAlertIds ?? this.seenAlertIds,
    lastChainUnderlying: clearLastChainUnderlying
        ? null
        : lastChainUnderlying ?? this.lastChainUnderlying,
    localeOverride: clearLocaleOverride
        ? null
        : localeOverride ?? this.localeOverride,
  );

  @override
  bool operator ==(Object other) =>
      other is LocalPrefsData &&
      setEquals(other.favouriteIds, favouriteIds) &&
      listEquals(other.watchlistOrder, watchlistOrder) &&
      listEquals(other.pendingOrderRecords, pendingOrderRecords) &&
      other.riskNoticeAcked == riskNoticeAcked &&
      other.hapticsEnabled == hapticsEnabled &&
      other.analyticsConsent == analyticsConsent &&
      other.notificationExplainerShown == notificationExplainerShown &&
      setEquals(other.seenAlertIds, seenAlertIds) &&
      other.lastChainUnderlying == lastChainUnderlying &&
      other.localeOverride == localeOverride;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(favouriteIds),
    Object.hashAll(watchlistOrder),
    Object.hashAll(pendingOrderRecords),
    riskNoticeAcked,
    hapticsEnabled,
    analyticsConsent,
    notificationExplainerShown,
    Object.hashAllUnordered(seenAlertIds),
    lastChainUnderlying,
    localeOverride,
  );

  @override
  String toString() =>
      'LocalPrefsData(riskNoticeAcked: $riskNoticeAcked, hapticsEnabled: '
      '$hapticsEnabled, analyticsConsent: $analyticsConsent, seenAlertIds: '
      '${seenAlertIds.length}, lastChainUnderlying: $lastChainUnderlying, '
      'localeOverride: $localeOverride)';
}

abstract interface class LocalPrefs {
  /// The current values. Reflects an [update] at once, before it is on disk.
  LocalPrefsData get data;

  Future<void> update(LocalPrefsData Function(LocalPrefsData current) change);

  /// Back to [LocalPrefsData.defaults] and the file deleted.
  Future<void> clear();
}

import 'package:flutter/foundation.dart';

import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

/// What covers the shell. [opaqueDepth] 0 means the shell is on top;
/// [topOpaque] is the top opaque route's id, null when that route has none
/// (risk notice, Socket Lab, clock), which hides every screen.
@immutable
class CoveredState {
  const CoveredState({required this.topOpaque, required this.opaqueDepth});

  static const shell = CoveredState(topOpaque: null, opaqueDepth: 0);

  final ScreenId? topOpaque;
  final int opaqueDepth;

  @override
  bool operator ==(Object other) =>
      other is CoveredState &&
      other.topOpaque == topOpaque &&
      other.opaqueDepth == opaqueDepth;

  @override
  int get hashCode => Object.hash(topOpaque, opaqueDepth);

  @override
  String toString() =>
      'CoveredState(topOpaque: $topOpaque, opaqueDepth: $opaqueDepth)';
}

/// Trading phase, same values as the server's `MarketPhase`.
enum MarketPhase { preOpen, open, closed }

/// The server's market clock as last reported (`GET /clock`, `clock` frames,
/// `welcome.clock`). Market time = server wall time + [marketOffsetMs].
class MarketClockState {
  const MarketClockState({
    required this.phase,
    required this.marketOffsetMs,
    required this.mode,
    required this.tradingDay,
    this.nextPhaseAt,
    this.overridden = false,
  });

  factory MarketClockState.fromJson(Map<String, Object?> j) {
    final next = j['nextPhaseAt'];
    return MarketClockState(
      phase: MarketPhase.values.byName(j['phase']! as String),
      marketOffsetMs: (j['marketOffsetMs'] as num? ?? 0).toInt(),
      mode: j['mode'] as String? ?? 'real',
      tradingDay: j['tradingDay'] as String? ?? '',
      nextPhaseAt: switch (next) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        final String iso => DateTime.parse(iso),
        _ => null,
      },
      overridden: j['overridden'] as bool? ?? false,
    );
  }

  /// Used until the server reports a clock: always open.
  static const fallback = MarketClockState(
    phase: MarketPhase.open,
    marketOffsetMs: 0,
    mode: 'real',
    tradingDay: '',
  );

  final MarketPhase phase;
  final int marketOffsetMs;

  /// `demo` or `real`.
  final String mode;

  /// `yyyy-MM-dd` in IST.
  final String tradingDay;
  final DateTime? nextPhaseAt;

  /// Demo mode or a debug jump: shows the "Demo clock" chip.
  final bool overridden;

  DateTime marketNow(DateTime serverNow) =>
      serverNow.add(Duration(milliseconds: marketOffsetMs));

  MarketClockState copyWith({
    MarketPhase? phase,
    int? marketOffsetMs,
    String? mode,
    String? tradingDay,
    DateTime? nextPhaseAt,
    bool? overridden,
  }) => MarketClockState(
    phase: phase ?? this.phase,
    marketOffsetMs: marketOffsetMs ?? this.marketOffsetMs,
    mode: mode ?? this.mode,
    tradingDay: tradingDay ?? this.tradingDay,
    nextPhaseAt: nextPhaseAt ?? this.nextPhaseAt,
    overridden: overridden ?? this.overridden,
  );

  @override
  bool operator ==(Object other) =>
      other is MarketClockState &&
      other.phase == phase &&
      other.marketOffsetMs == marketOffsetMs &&
      other.mode == mode &&
      other.tradingDay == tradingDay &&
      other.nextPhaseAt == nextPhaseAt &&
      other.overridden == overridden;

  @override
  int get hashCode => Object.hash(
    phase,
    marketOffsetMs,
    mode,
    tradingDay,
    nextPhaseAt,
    overridden,
  );
}

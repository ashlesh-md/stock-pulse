import 'dart:math';

import 'package:market_server/market_server.dart';

/// 09:30:15 UTC = 15:00:15 IST on Wed 4 Nov 2026.
final now = DateTime.utc(2026, 11, 4, 9, 30, 15);

/// IST midnight that starts 4 Nov = 18:30 UTC on 3 Nov.
final todayIst = DateTime.utc(2026, 11, 3, 18, 30);

MarketEngine seededEngine({DateTime Function()? clock}) => MarketEngine(
  instruments,
  random: Random(42),
  clock: clock ?? () => now,
  intradayDays: 2,
  dailyDays: 400,
);

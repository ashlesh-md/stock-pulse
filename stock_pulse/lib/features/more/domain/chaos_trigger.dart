import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';

/// Asks the demo server to misbehave on purpose.
abstract interface class ChaosTrigger {
  Future<Result<void>> trigger(Chaos chaos);
}

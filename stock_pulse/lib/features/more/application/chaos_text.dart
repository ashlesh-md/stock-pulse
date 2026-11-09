import 'package:stock_pulse/core/l10n/strings/more_strings.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';

String chaosLabel(MoreStrings s, Chaos chaos) => switch (chaos) {
  Chaos.drop => s.dropConnection,
  Chaos.freeze => s.freezeServer,
  Chaos.skipSeq => s.skipSeq,
};

String chaosExplanation(MoreStrings s, Chaos chaos) => switch (chaos) {
  Chaos.drop => s.dropExplained,
  Chaos.freeze => s.freezeExplained,
  Chaos.skipSeq => s.skipSeqExplained,
};

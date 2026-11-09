
import 'package:market_server/src/ai/cards/card_envelope.dart';
import 'package:market_server/src/ai/cards/card_format.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_reads.dart';
import 'package:market_server/src/models.dart';

Map<String, Object?> quoteCard({
  required String id,
  required QuoteRead quote,
  required String name,
  required MarketPhase phase,
}) => cardEnvelope(
  id: id,
  type: 'quote',
  title: quote.id,
  asOf: quote.asOf,
  instruments: [quote.id],
  fallbackText:
      '${quote.id} ${formatInr(quote.ltp)} (${formatPct(quote.changePct)})',
  actions: [
    action('open_stock', 'Open stock', {'instrumentId': quote.id}),
    action('set_alert', 'Set alert', {'instrumentId': quote.id}),
  ],
  body: {
    'id': quote.id,
    'symbol': quote.id,
    'name': name,
    'ltp': r2(quote.ltp),
    'change': r2(quote.change),
    'changePct': r2(quote.changePct),
    'prevClose': r2(quote.prevClose),
    'phase': phase.name,
  },
);

Map<String, Object?> chartCard({
  required String id,
  required String instrumentId,
  required double prevClose,
  required List<Candle> candles,
  required DateTime asOf,
}) {
  final points = candles.length > 75
      ? candles.sublist(candles.length - 75)
      : candles;
  return cardEnvelope(
    id: id,
    type: 'chart',
    title: '$instrumentId today · 5m',
    asOf: asOf,
    instruments: [instrumentId],
    fallbackText: '$instrumentId 5-minute chart for today',
    actions: [
      action('open_chart', 'Open chart', {'instrumentId': instrumentId}),
    ],
    body: {
      'id': instrumentId,
      'interval': '5m',
      'prevClose': r2(prevClose),
      'points': [
        for (final c in points) [c.start.millisecondsSinceEpoch, r2(c.close)],
      ],
    },
  );
}

/// Table column: [format] is `price`, `pct` or `text`; [live] columns
/// follow the quote stream on the client.
class TableColumnJson {
  const TableColumnJson(
    this.key,
    this.label, {
    this.live = false,
    this.format = 'text',
  });

  final String key;
  final String label;
  final bool live;
  final String format;

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'live': live,
    'format': format,
  };
}

/// ≤ 5 rows; a row tap opens the stock (`row.id`), so no envelope action.
Map<String, Object?> tableCard({
  required String id,
  required String title,
  required DateTime asOf,
  required List<TableColumnJson> columns,
  required List<({String id, Map<String, Object?> cells})> rows,
  required String fallbackText,
}) {
  final shown = rows.take(5).toList();
  return cardEnvelope(
    id: id,
    type: 'table',
    title: title,
    asOf: asOf,
    instruments: [for (final r in shown) r.id],
    fallbackText: fallbackText,
    actions: const [],
    body: {
      'columns': [for (final c in columns) c.toJson()],
      'rows': [
        for (final r in shown) {'id': r.id, 'cells': r.cells},
      ],
    },
  );
}

/// Table cells for one quote.
Map<String, Object?> quoteRowCells(QuoteRead q) => {
  'symbol': q.id,
  'ltp': r2(q.ltp),
  'changePct': r2(q.changePct),
};

/// "RELIANCE +1.20% · HDFCBANK −0.40%".
String movesLine(List<QuoteRead> quotes) =>
    quotes.map((q) => '${q.id} ${formatPct(q.changePct)}').join(' · ');

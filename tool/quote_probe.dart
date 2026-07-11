// 手動驗證工具：用 App 實際的 YahooQuoteService 打真實端點，
// 確認即時報價與歷史日線在本機網路環境可用。
// 執行：dart run tool/quote_probe.dart
// ignore_for_file: avoid_print — 本檔為手動驗證 CLI 工具，print 即輸出介面

import 'package:http/http.dart' as http;
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/models/stock_quote.dart';
import 'package:stock_portfolio_app/services/historical_price_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';
import 'package:stock_portfolio_app/services/yahoo_quote_service.dart';

Future<void> main() async {
  MarketSessionResolver.InitializeTimeZoneDatabase();

  final YahooQuoteService quote_service = YahooQuoteService();
  print('== 即時報價（v7 主路徑 + chart 備援）==');
  final Map<String, StockQuote> quotes = await quote_service
      .FetchRealtimeQuotes(<String>['NVDA', 'VOO', 'AAPL', 'GOOG']);
  if (quotes.isEmpty) {
    print('  失敗：無法取得任何報價（退避中: ${quote_service.is_backing_off}）');
  } else {
    for (final StockQuote q in quotes.values) {
      print('  ${q.symbol}: 盤中=${q.regular_price} '
          '盤前=${q.pre_price} 盤後=${q.post_price} state=${q.market_state}');
    }
  }

  print('== 歷史日線（近 30 天）==');
  final AppDatabase database = AppDatabase.Memory();
  final http.Client client = http.Client();
  final HistoricalPriceService history_service = HistoricalPriceService(
    historical_price_dao: database.historicalPriceDao,
    http_client: client,
  );
  final Map<int, double>? closes =
      await history_service.FetchDailyCloses('NVDA', 20260610, 20260710);
  if (closes == null || closes.isEmpty) {
    print('  失敗：無法取得歷史日線');
  } else {
    final List<int> dates = closes.keys.toList()..sort();
    print('  取得 ${closes.length} 天，'
        '最後一天 ${dates.last} 收盤 ${closes[dates.last]}');
  }
  client.close();
  await database.close();
}

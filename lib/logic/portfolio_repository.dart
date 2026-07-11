// 投資組合 Repository（facade）：UI 層唯一的資料入口，
// 聚合 CSV 匯入、持倉計算、報價輪詢、歷史曲線與資料庫存取。

import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../models/holding_position.dart';
import '../models/market_session.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_quote.dart';
import '../models/stock_transaction.dart';
import '../models/ohlcv_candle.dart';
import '../models/symbol_search_result.dart';
import '../services/backup_service.dart';
import '../services/csv_transaction_importer.dart';
import '../services/dividend_service.dart';
import '../services/historical_price_service.dart';
import '../services/market_session_resolver.dart';
import '../services/quote_polling_scheduler.dart';
import '../services/stock_symbol_search_service.dart';
import '../services/yahoo_quote_service.dart';
import 'portfolio_calculator.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   PortfolioRepository
 *
 * @brief   UI 與底層模組之間的唯一介面。UI 不直接碰資料庫、網路或計算引擎。
 *
 * @note    報價更新透過 quote_scheduler（ChangeNotifier）通知 UI；
 *          其餘查詢皆為 Future 回傳不可變模型。
 */
class PortfolioRepository {
  /// 可供比較的大盤指數：顯示名稱 → Yahoo 代號。
  static const Map<String, String> BENCHMARK_INDEXES = <String, String>{
    'S&P 500': '^GSPC',
    '那斯達克': '^IXIC',
    '台灣加權': '^TWII',
  };

  final AppDatabase database;
  final CsvTransactionImporter csv_importer;
  final PortfolioCalculator calculator;
  final MarketSessionResolver session_resolver;
  final YahooQuoteService quote_service;
  final HistoricalPriceService historical_price_service;
  final StockSymbolSearchService symbol_search_service;
  final DividendService dividend_service;
  late final BackupService backup_service;
  late final QuotePollingScheduler quote_scheduler;

  PortfolioRepository({
    required this.database,
    http.Client? http_client,
  })  : csv_importer = CsvTransactionImporter(),
        calculator = PortfolioCalculator(),
        session_resolver = MarketSessionResolver(),
        quote_service = YahooQuoteService(http_client: http_client),
        symbol_search_service =
            StockSymbolSearchService(http_client: http_client),
        dividend_service = DividendService(
          dividend_dao: database.dividendDao,
          http_client: http_client,
        ),
        historical_price_service = HistoricalPriceService(
          historical_price_dao: database.historicalPriceDao,
          http_client: http_client,
        ) {
    backup_service = BackupService(database: database);
    quote_scheduler = QuotePollingScheduler(
      quote_service: quote_service,
      quote_cache_dao: database.quoteCacheDao,
      ProvideTrackedSymbols: GetTrackedSymbols,
    );
  }

  /// App 內顯示用的成本計算方法名稱（加權平均法）。
  String get cost_method_name => PortfolioCalculator.COST_METHOD_NAME;

  /// 匯入 CSV 全文並回傳統計摘要（支援重複匯入去重）。
  Future<ImportSummary> ImportTransactionsFromCsv(String csv_content) {
    return csv_importer.ImportCsvIntoDatabase(
        csv_content, database.transactionDao);
  }

  /// 取得全部持倉（依加權平均法計算，含已清倉代號）。
  Future<List<HoldingPosition>> GetHoldingPositions() async {
    final List<StockTransaction> transactions =
        await database.transactionDao.GetAllTransactions();
    return calculator.CalculateHoldingPositions(transactions);
  }

  /// 取得單一代號的交易明細（依日期排序）。
  Future<List<StockTransaction>> GetTransactionsForSymbol(String symbol) {
    return database.transactionDao.GetTransactionsBySymbol(symbol);
  }

  /// 取得需要追蹤報價的代號清單：持有中的個股 ∪ 自選追蹤清單。
  Future<List<String>> GetTrackedSymbols() async {
    final List<HoldingPosition> positions = await GetHoldingPositions();
    final List<WatchlistSymbol> watchlist =
        await database.watchlistDao.GetAllSymbols();
    final Set<String> symbols = <String>{
      ...positions
          .where((HoldingPosition p) => !p.is_closed)
          .map((HoldingPosition p) => p.symbol),
      ...watchlist.map((WatchlistSymbol w) => w.symbol),
    };
    return symbols.toList();
  }

  /// 取得自選追蹤清單（依加入時間排序）。
  Future<List<WatchlistSymbol>> GetWatchlist() {
    return database.watchlistDao.GetAllSymbols();
  }

  /// 加入自選追蹤；回傳 true 表示實際新增（false = 已在清單中）。
  Future<bool> AddToWatchlist(String symbol, String name) {
    return database.watchlistDao.AddSymbol(
        symbol, name, DateTime.now().millisecondsSinceEpoch);
  }

  /// 移除自選追蹤。
  Future<void> RemoveFromWatchlist(String symbol) {
    return database.watchlistDao.RemoveSymbol(symbol);
  }

  /// 抓取個股詳情頁的 K 線資料（日/週/月）；失敗回傳 null。
  Future<List<OhlcvCandle>?> FetchOhlcvCandles(
      String symbol, CandleInterval interval) {
    return historical_price_service.FetchOhlcvCandles(symbol, interval);
  }

  /*
   *  @fn      Future<List<PortfolioSnapshot>> GetPortfolioHistory()
   *
   *  @brief   ( 取得資產曲線資料：先增量同步各檔歷史股價，再逐日重建市值與成本 )
   *
   *  @return  由舊到新的每日快照；無交易時回傳空清單
   *
   *  @note    歷史股價同步失敗時使用既有快取，曲線仍可畫出（可能缺最新幾天）。
   */
  Future<List<PortfolioSnapshot>> GetPortfolioHistory() async {
    final List<StockTransaction> transactions =
        await database.transactionDao.GetAllTransactions();
    if (transactions.isEmpty) {
      return <PortfolioSnapshot>[];
    }

    // 各代號最早交易日
    final Map<String, int> earliest_by_symbol = <String, int>{};
    for (final StockTransaction tx in transactions) {
      final int? current = earliest_by_symbol[tx.symbol];
      if (current == null || tx.trade_date < current) {
        earliest_by_symbol[tx.symbol] = tx.trade_date;
      }
    }

    // 增量同步歷史股價（失敗靜默，用既有快取）
    for (final MapEntry<String, int> entry in earliest_by_symbol.entries) {
      await historical_price_service.SyncHistoricalCloses(
          entry.key, entry.value);
    }

    final Map<String, Map<int, double>> closes =
        await database.historicalPriceDao.GetAllHistoricalCloses();
    final DateTime now = DateTime.now();
    final int today = now.year * 10000 + now.month * 100 + now.day;
    return calculator.CalculateDailyPortfolioHistory(
        transactions, closes, today);
  }

  /*
   *  @fn      Future<bool> AddManualTransaction(StockTransaction transaction)
   *
   *  @brief   ( 手動新增一筆交易，與 CSV 匯入共用去重規則 )
   *
   *  @param   transaction - 使用者輸入的交易
   *
   *  @return  true 表示新增成功；false 表示與既有紀錄重複被忽略
   */
  Future<bool> AddManualTransaction(StockTransaction transaction) {
    return database.transactionDao.InsertIgnoreTransaction(transaction);
  }

  /// 以關鍵字搜尋股票代號（手動記帳的自動完成）。
  Future<List<SymbolSearchResult>> SearchSymbols(String query) {
    return symbol_search_service.SearchSymbols(query);
  }

  /// 查詢單一代號的即時報價（手動記帳時預帶現價用）；失敗回傳 null。
  Future<StockQuote?> FetchSingleQuote(String symbol) async {
    final Map<String, StockQuote> quotes =
        await quote_service.FetchRealtimeQuotes(<String>[symbol]);
    return quotes[symbol];
  }

  /*
   *  @fn      Future<Map<int, double>> GetBenchmarkCloses(String index_symbol, int from_date)
   *
   *  @brief   ( 取得大盤指數的日收盤價：先增量同步再讀快取 )
   *
   *  @param   index_symbol - 指數代號（^GSPC / ^IXIC / ^TWII）
   *  @param   from_date - 需要的最早日期（yyyyMMdd）
   *
   *  @return  {yyyyMMdd: 收盤}；同步失敗時回傳既有快取（可能為空）
   */
  Future<Map<int, double>> GetBenchmarkCloses(
      String index_symbol, int from_date) async {
    await historical_price_service.SyncHistoricalCloses(
        index_symbol, from_date);
    return database.historicalPriceDao.GetHistoricalCloses(index_symbol);
  }

  /*
   *  @fn      Future<Map<String, double>> GetDividendIncomeBySymbol()
   *
   *  @brief   ( 取得各代號的累計股息收入：先同步配息事件再以除息日持股計算 )
   *
   *  @return  {symbol: 累計股息}；同步失敗時使用既有快取
   */
  Future<Map<String, double>> GetDividendIncomeBySymbol() async {
    final List<StockTransaction> transactions =
        await database.transactionDao.GetAllTransactions();
    if (transactions.isEmpty) {
      return <String, double>{};
    }
    final Map<String, int> earliest_by_symbol = <String, int>{};
    for (final StockTransaction tx in transactions) {
      final int? current = earliest_by_symbol[tx.symbol];
      if (current == null || tx.trade_date < current) {
        earliest_by_symbol[tx.symbol] = tx.trade_date;
      }
    }
    for (final MapEntry<String, int> entry in earliest_by_symbol.entries) {
      await dividend_service.SyncDividendEvents(entry.key, entry.value);
    }
    final Map<String, Map<int, double>> events =
        await database.dividendDao.GetAllDividendEvents();
    return calculator.CalculateDividendIncomeBySymbol(transactions, events);
  }

  /*
   *  @fn      Future<double?> CalculatePortfolioXirr(double total_market_value, Map<String, double> dividend_income)
   *
   *  @brief   ( 計算整體組合的資金加權年化報酬率 XIRR )
   *
   *  @param   total_market_value - 今日總市值
   *  @param   dividend_income - 各代號累計股息（視為今日收到的正現金流）
   *
   *  @return  年化報酬率；資料不足無法求解回傳 null
   */
  Future<double?> CalculatePortfolioXirr(
      double total_market_value, Map<String, double> dividend_income) async {
    final List<StockTransaction> transactions =
        await database.transactionDao.GetAllTransactions();
    if (transactions.isEmpty) {
      return null;
    }
    final DateTime now = DateTime.now();
    final int today = now.year * 10000 + now.month * 100 + now.day;
    final List<(int, double)> cashflows = <(int, double)>[
      for (final StockTransaction tx in transactions)
        (
          tx.trade_date,
          tx.transaction_type == TransactionType.buy
              ? -tx.purchase_price * tx.quantity
              : tx.purchase_price * tx.quantity
        ),
      // 股息以「今日一次收到」近似（除息日分攤的差異對年化影響極小）
      (
        today,
        total_market_value +
            dividend_income.values
                .fold<double>(0.0, (double sum, double v) => sum + v)
      ),
    ];
    return calculator.CalculateXirr(cashflows);
  }

  /// 判斷目前美股時段。
  MarketSession GetCurrentMarketSession() {
    return session_resolver.ResolveCurrentMarketSession();
  }

  /// 取得記憶體中最新報價（含快取載入的）。
  Map<String, StockQuote> GetLatestQuotes() {
    return Map<String, StockQuote>.unmodifiable(quote_scheduler.latest_quotes);
  }

  /// 啟動背景報價輪詢。
  Future<void> StartBackgroundQuotePolling() {
    return quote_scheduler.Start();
  }

  /// 停止背景報價輪詢並釋放資料庫連線。
  Future<void> DisposeResources() async {
    quote_scheduler.Stop();
    await database.close();
  }
}

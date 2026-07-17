// 投資組合 Repository（facade）：UI 層唯一的資料入口，
// 聚合 CSV 匯入、持倉計算、報價輪詢、歷史曲線與資料庫存取。

import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../database/tombstone_dao.dart';
import '../models/holding_position.dart';
import '../models/market_session.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_news_item.dart';
import '../models/stock_quote.dart';
import '../models/stock_transaction.dart';
import '../models/ohlcv_candle.dart';
import '../models/symbol_search_result.dart';
import '../services/backup_service.dart';
import '../services/csv_transaction_importer.dart';
import '../services/dividend_service.dart';
import '../services/google_drive_sync_service.dart';
import '../services/historical_price_service.dart';
import '../services/market_session_resolver.dart';
import '../services/quote_polling_scheduler.dart';
import '../services/stock_symbol_search_service.dart';
import '../services/yahoo_quote_service.dart';
import 'market_registry.dart';
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
  late final GoogleDriveSyncService drive_sync_service;
  late final QuotePollingScheduler quote_scheduler;

  /// 目前顯示幣別（'USD' | 'TWD'）。由 controller 依使用者設定注入，
  /// 影響追蹤代號集合（是否加入匯率）與資產曲線的換算基準。
  String display_currency = 'USD';

  PortfolioRepository({required this.database, http.Client? http_client})
    : csv_importer = CsvTransactionImporter(),
      calculator = PortfolioCalculator(),
      session_resolver = MarketSessionResolver(),
      quote_service = YahooQuoteService(http_client: http_client),
      symbol_search_service = StockSymbolSearchService(
        http_client: http_client,
      ),
      dividend_service = DividendService(
        dividend_dao: database.dividendDao,
        http_client: http_client,
      ),
      historical_price_service = HistoricalPriceService(
        historical_price_dao: database.historicalPriceDao,
        http_client: http_client,
      ) {
    backup_service = BackupService(database: database);
    drive_sync_service = GoogleDriveSyncService(backup_service: backup_service);
    quote_scheduler = QuotePollingScheduler(
      quote_service: quote_service,
      quote_cache_dao: database.quoteCacheDao,
      ProvideTrackedSymbols: GetTrackedSymbols,
    );
  }

  /// App 內顯示用的成本計算方法名稱（加權平均法）。
  String get cost_method_name => PortfolioCalculator.COST_METHOD_NAME;

  /// 匯入 CSV 全文並回傳統計摘要（支援重複匯入去重）。
  Future<ImportSummary> ImportTransactionsFromCsv(
    String csv_content, {
    CsvColumnMapping? column_mapping,
  }) {
    return csv_importer.ImportCsvIntoDatabase(
      csv_content,
      database.transactionDao,
      column_mapping: column_mapping,
    );
  }

  /// 取得全部持倉（依加權平均法計算，含已清倉代號）。
  Future<List<HoldingPosition>> GetHoldingPositions() async {
    final List<StockTransaction> transactions = await database.transactionDao
        .GetAllTransactions();
    return calculator.CalculateHoldingPositions(transactions);
  }

  /// 取得單一代號的交易明細（依日期排序）。
  Future<List<StockTransaction>> GetTransactionsForSymbol(String symbol) {
    return database.transactionDao.GetTransactionsBySymbol(symbol);
  }

  /// 取得需要追蹤報價的代號清單：持有中的個股 ∪ 自選追蹤清單。
  /// 當任一代號屬台股、或顯示幣別為 TWD 時，額外加入匯率代號 'TWD=X'，
  /// 讓匯率跟隨相同的報價輪詢與快取管線更新。
  Future<List<String>> GetTrackedSymbols() async {
    final List<HoldingPosition> positions = await GetHoldingPositions();
    final List<WatchlistSymbol> watchlist = await database.watchlistDao
        .GetAllSymbols();
    final Set<String> symbols = <String>{
      ...positions
          .where((HoldingPosition p) => !p.is_closed)
          .map((HoldingPosition p) => p.symbol),
      ...watchlist.map((WatchlistSymbol w) => w.symbol),
    };
    final bool has_tw_symbol = symbols.any(
      (String s) => ResolveMarketForSymbol(s).market_id == 'tw',
    );
    if (has_tw_symbol || display_currency == 'TWD') {
      symbols.add(USD_TWD_FX_SYMBOL);
    }
    return symbols.toList();
  }

  /// 取得自選追蹤清單（依加入時間排序）。
  Future<List<WatchlistSymbol>> GetWatchlist() {
    return database.watchlistDao.GetAllSymbols();
  }

  /// 加入自選追蹤；回傳 true 表示實際新增（false = 已在清單中）。
  Future<bool> AddToWatchlist(
    String symbol,
    String name, {
    String group_name = '自選',
  }) async {
    final bool added = await database.watchlistDao.AddSymbol(
      symbol,
      name,
      DateTime.now().millisecondsSinceEpoch,
      group_name: group_name,
    );
    if (added) {
      await database.tombstoneDao.RemoveTombstone(
        TombstoneDao.KIND_WATCHLIST,
        symbol,
      );
    }
    return added;
  }

  /// 更改追蹤股的分類。
  Future<void> UpdateWatchlistGroup(String symbol, String group_name) {
    return database.watchlistDao.UpdateSymbolGroup(symbol, group_name);
  }

  /// 移除自選追蹤並留下同步墓碑。
  Future<void> RemoveFromWatchlist(String symbol) async {
    await database.watchlistDao.RemoveSymbol(symbol);
    await database.tombstoneDao.AddTombstone(
      TombstoneDao.KIND_WATCHLIST,
      symbol,
    );
  }

  /// 抓取個股詳情頁的 K 線資料（日/週/月＋時間範圍）；失敗回傳 null。
  Future<List<OhlcvCandle>?> FetchOhlcvCandles(
    String symbol,
    CandleInterval interval, {
    CandleRange? range,
  }) {
    return historical_price_service.FetchOhlcvCandles(
      symbol,
      interval,
      range: range,
    );
  }

  /*
   *  @fn      Future<List<PortfolioSnapshot>> GetPortfolioHistory()
   *
   *  @brief   ( 取得資產曲線資料：先增量同步各檔歷史股價，再逐日重建市值與成本 )
   *
   *  @return  由舊到新的每日快照；無交易時回傳空清單
   *
   *  @note    歷史股價同步失敗時使用既有快取，曲線仍可畫出（可能缺最新幾天）。
   *           組合含台股代號或顯示幣別為 TWD 時，額外同步 'TWD=X' 歷史匯率，
   *           逐日以往前遞補換算到顯示幣別。
   */
  Future<List<PortfolioSnapshot>> GetPortfolioHistory() async {
    final List<StockTransaction> transactions = await database.transactionDao
        .GetAllTransactions();
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
        entry.key,
        entry.value,
      );
    }

    // 需要換匯時（含台股代號或顯示 TWD），同步歷史匯率並取出 {yyyyMMdd: 匯率}
    Map<int, double> usd_twd_by_date = const <int, double>{};
    final bool needs_fx =
        display_currency == 'TWD' ||
        earliest_by_symbol.keys.any(
          (String s) => ResolveMarketForSymbol(s).market_id == 'tw',
        );
    if (needs_fx) {
      final int earliest_trade_date = earliest_by_symbol.values.reduce(
        (int a, int b) => a < b ? a : b,
      );
      await historical_price_service.SyncHistoricalCloses(
        USD_TWD_FX_SYMBOL,
        earliest_trade_date,
      );
      usd_twd_by_date = await database.historicalPriceDao.GetHistoricalCloses(
        USD_TWD_FX_SYMBOL,
      );
    }

    final Map<String, Map<int, double>> closes = await database
        .historicalPriceDao
        .GetAllHistoricalCloses();
    final DateTime now = DateTime.now();
    final int today = now.year * 10000 + now.month * 100 + now.day;
    return calculator.CalculateDailyPortfolioHistory(
      transactions,
      closes,
      today,
      display_currency: display_currency,
      usd_twd_by_date: usd_twd_by_date,
    );
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
  Future<bool> AddManualTransaction(StockTransaction transaction) async {
    final bool inserted = await database.transactionDao.InsertIgnoreTransaction(
      transaction,
    );
    if (inserted) {
      // 重新加入曾刪除的相同交易 → 撤銷墓碑
      await database.tombstoneDao.RemoveTombstone(
        TombstoneDao.KIND_TRANSACTION,
        TombstoneDao.BuildTransactionKey(transaction),
      );
    }
    return inserted;
  }

  /// 刪除單筆交易並留下同步墓碑（避免雲端同步時復活）。
  Future<bool> DeleteTransaction(StockTransaction transaction) async {
    if (transaction.id == null) {
      return false;
    }
    final bool deleted = await database.transactionDao.DeleteTransactionById(
      transaction.id!,
    );
    if (deleted) {
      await database.tombstoneDao.AddTombstone(
        TombstoneDao.KIND_TRANSACTION,
        TombstoneDao.BuildTransactionKey(transaction),
      );
    }
    return deleted;
  }

  /// 以關鍵字搜尋股票代號（手動記帳的自動完成）。
  Future<List<SymbolSearchResult>> SearchSymbols(String query) {
    return symbol_search_service.SearchSymbols(query);
  }

  /// 抓取個股相關新聞（詳情頁用）；失敗回傳空清單。
  Future<List<StockNewsItem>> FetchNewsForSymbol(
    String symbol, {
    String? display_name,
  }) {
    return symbol_search_service.FetchNewsForSymbol(
      symbol,
      display_name: display_name,
    );
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
    String index_symbol,
    int from_date,
  ) async {
    await historical_price_service.SyncHistoricalCloses(
      index_symbol,
      from_date,
    );
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
    final List<StockTransaction> transactions = await database.transactionDao
        .GetAllTransactions();
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
    final Map<String, Map<int, double>> events = await database.dividendDao
        .GetAllDividendEvents();
    return calculator.CalculateDividendIncomeBySymbol(transactions, events);
  }

  /*
   *  @fn      Future<double?> CalculatePortfolioXirr(double total_market_value, Map<String, double> dividend_income)
   *
   *  @brief   ( 計算整體組合的資金加權年化報酬率 XIRR )
   *
   *  @param   total_market_value - 今日總市值（已換算為顯示幣別）
   *  @param   dividend_income - 各代號累計股息（原生幣別，視為今日收到的正現金流）
   *  @param   usd_twd_rate - 現時 1 美元兌台幣匯率；顯示 TWD 時期末市值與股息換算用
   *
   *  @return  年化報酬率；資料不足無法求解回傳 null
   *
   *  @note    逐筆交易現金流以「交易日匯率（往前遞補）」換算到顯示幣別，
   *           期末市值與股息以現時匯率換算，全美股 USD 顯示時不觸發換算。
   */
  Future<double?> CalculatePortfolioXirr(
    double total_market_value,
    Map<String, double> dividend_income, {
    double? usd_twd_rate,
  }) async {
    final List<StockTransaction> transactions = await database.transactionDao
        .GetAllTransactions();
    if (transactions.isEmpty) {
      return null;
    }
    final DateTime now = DateTime.now();
    final int today = now.year * 10000 + now.month * 100 + now.day;

    // 資料未滿 30 天不顯示 XIRR：期間太短年化會出現數百 % 的無意義數字
    final int earliest = transactions
        .map((StockTransaction t) => t.trade_date)
        .reduce((int a, int b) => a < b ? a : b);
    final DateTime earliest_date = DateTime(
      earliest ~/ 10000,
      (earliest ~/ 100) % 100,
      earliest % 100,
    );
    if (now.difference(earliest_date).inDays < 30) {
      return null;
    }

    // 交易日匯率史（往前遞補用）；顯示 USD 且無台股時為空，不觸發換算
    final double effective_rate = usd_twd_rate ?? 0.0;
    Map<int, double> usd_twd_by_date = const <int, double>{};
    final bool needs_fx =
        display_currency == 'TWD' ||
        transactions.any(
          (StockTransaction t) =>
              ResolveMarketForSymbol(t.symbol).market_id == 'tw',
        );
    if (needs_fx) {
      usd_twd_by_date = await database.historicalPriceDao.GetHistoricalCloses(
        USD_TWD_FX_SYMBOL,
      );
    }
    final List<int> sorted_rate_dates = usd_twd_by_date.keys.toList()..sort();

    // 各代號累計股息以現時匯率換算到顯示幣別後加總
    double converted_dividends = 0.0;
    for (final MapEntry<String, double> entry in dividend_income.entries) {
      converted_dividends += PortfolioCalculator.ConvertCurrencyValue(
        entry.value,
        ResolveMarketForSymbol(entry.key).currency,
        display_currency,
        effective_rate,
      );
    }

    final List<(int, double)> cashflows = <(int, double)>[
      for (final StockTransaction tx in transactions)
        (
          tx.trade_date,
          PortfolioCalculator.ConvertCurrencyValue(
            tx.transaction_type == TransactionType.buy
                ? -tx.purchase_price * tx.quantity
                : tx.purchase_price * tx.quantity,
            ResolveMarketForSymbol(tx.symbol).currency,
            display_currency,
            PortfolioCalculator.ResolveForwardFilledRate(
              sorted_rate_dates,
              usd_twd_by_date,
              tx.trade_date,
            ),
          ),
        ),
      // 股息以「今日一次收到」近似（除息日分攤的差異對年化影響極小）
      // total_market_value 已為顯示幣別，股息以現時匯率換算後加入
      (today, total_market_value + converted_dividends),
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

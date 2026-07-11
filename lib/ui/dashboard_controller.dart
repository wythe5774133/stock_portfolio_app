// 儀表板控制器：UI 層的狀態中樞。
// 只透過 PortfolioRepository 取得資料，不直接碰資料庫、網路或計算引擎。

import 'package:flutter/foundation.dart';

import '../logic/portfolio_calculator.dart';
import '../logic/portfolio_repository.dart';
import '../models/holding_position.dart';
import '../models/market_session.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_quote.dart';
import '../models/stock_transaction.dart';
import '../models/symbol_search_result.dart';
import '../services/app_settings_store.dart';
import '../services/csv_transaction_importer.dart';
import 'theme/profit_color_scheme.dart';

/// 資產曲線的時間範圍選項。
enum CurveRange {
  one_month,
  three_months,
  six_months,
  year_to_date,
  one_year,
  two_years,
  all,
}

/// 時間範圍的顯示標籤。
String FormatCurveRange(CurveRange range) {
  switch (range) {
    case CurveRange.one_month:
      return '1月';
    case CurveRange.three_months:
      return '3月';
    case CurveRange.six_months:
      return '6月';
    case CurveRange.year_to_date:
      return 'YTD';
    case CurveRange.one_year:
      return '1年';
    case CurveRange.two_years:
      return '2年';
    case CurveRange.all:
      return '全部';
  }
}

/// 個股在列表中的顯示資料（現價與損益已算好，widget 只負責呈現）。
class HoldingDisplayRow {
  final HoldingPosition position;
  final double? current_price; // 依時段選出的顯示價格
  final String price_source_label; // 價格來源標示（盤中/盤前/盤後/均價）
  final double market_value; // 市值（無報價時以成本代替）
  final double unrealized_pnl; // 未實現損益
  final double unrealized_pnl_percent; // 未實現損益 %

  const HoldingDisplayRow({
    required this.position,
    required this.current_price,
    required this.price_source_label,
    required this.market_value,
    required this.unrealized_pnl,
    required this.unrealized_pnl_percent,
  });
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   DashboardController
 *
 * @brief   儀表板狀態控制器：持倉、資產曲線、即時報價、匯入流程與配色設定。
 *
 * @note    報價更新由 repository 的 quote_scheduler（ChangeNotifier）推播，
 *          本類別轉發給 UI；所有金額計算集中於此，widget 不做計算。
 */
class DashboardController extends ChangeNotifier {
  static const String SETTING_KEY_COLOR_CONVENTION = 'profit_color_convention';

  final PortfolioRepository repository;
  final AppSettingsStore settings_store;

  List<HoldingPosition> holdings = <HoldingPosition>[];
  List<PortfolioSnapshot> history = <PortfolioSnapshot>[];
  bool is_loading = true;
  bool is_history_loading = false;
  ProfitColorConvention color_convention = ProfitColorConvention.us;

  // 資產曲線：時間範圍與大盤比較狀態
  CurveRange curve_range = CurveRange.all;
  final Set<String> selected_benchmarks = <String>{}; // 指數代號（^GSPC 等）
  final Map<String, Map<int, double>> benchmark_closes =
      <String, Map<int, double>>{};
  bool is_benchmark_loading = false;

  DashboardController({
    required this.repository,
    AppSettingsStore? settings_store,
  }) : settings_store = settings_store ?? const AppSettingsStore() {
    repository.quote_scheduler.addListener(_OnQuotesUpdated);
  }

  /// 目前配色方案。
  ProfitColorScheme get profit_colors => ProfitColorScheme(color_convention);

  /// 目前美股時段。
  MarketSession get current_session =>
      repository.quote_scheduler.current_session;

  /// 最後成功更新報價的時間。
  DateTime? get last_updated_at => repository.quote_scheduler.last_updated_at;

  /// 報價是否暫時無法取得（連續失敗中）。
  bool get is_quote_unavailable =>
      repository.quote_scheduler.is_quote_unavailable;

  /// 成本計算方法名稱（UI 標示用）。
  String get cost_method_name => repository.cost_method_name;

  /*
   *  @fn      Future<void> InitializeDashboard()
   *
   *  @brief   ( 啟動流程：載入設定與持倉、啟動背景輪詢、非同步載入資產曲線 )
   *
   *  @return  None
   *
   *  @note    資產曲線需要抓歷史股價，可能較慢，因此獨立於主載入流程。
   */
  Future<void> InitializeDashboard() async {
    final Map<String, dynamic> settings = await settings_store.LoadSettings();
    color_convention = ParseProfitColorConvention(
        settings[SETTING_KEY_COLOR_CONVENTION] as String?);

    await ReloadHoldings();
    is_loading = false;
    notifyListeners();

    await repository.StartBackgroundQuotePolling();
    await ReloadPortfolioHistory();
  }

  /// 重新載入持倉清單。
  Future<void> ReloadHoldings() async {
    holdings = await repository.GetHoldingPositions();
    notifyListeners();
  }

  /// 重新載入資產曲線（含增量同步歷史股價）。
  Future<void> ReloadPortfolioHistory() async {
    is_history_loading = true;
    notifyListeners();
    try {
      history = await repository.GetPortfolioHistory();
    } finally {
      is_history_loading = false;
      notifyListeners();
    }
  }

  /*
   *  @fn      Future<ImportSummary> ImportCsvContent(String csv_content)
   *
   *  @brief   ( 匯入 CSV 全文並刷新持倉、報價與資產曲線 )
   *
   *  @param   csv_content - CSV 檔案全文
   *
   *  @return  ImportSummary - 供 UI 顯示新增/重複/跳過統計
   */
  Future<ImportSummary> ImportCsvContent(String csv_content) async {
    final ImportSummary summary =
        await repository.ImportTransactionsFromCsv(csv_content);
    await ReloadHoldings();
    // 匯入後立即抓一次新持倉的報價，並重建資產曲線
    await repository.quote_scheduler.PollQuotesNow();
    await ReloadPortfolioHistory();
    return summary;
  }

  /// 手動立即更新報價。
  Future<void> RefreshQuotesNow() async {
    await repository.quote_scheduler.PollQuotesNow();
  }

  /*
   *  @fn      Future<bool> AddManualTransaction(StockTransaction transaction)
   *
   *  @brief   ( 手動新增一筆交易並刷新持倉、報價與資產曲線 )
   *
   *  @return  true 新增成功；false 與既有紀錄重複
   */
  Future<bool> AddManualTransaction(StockTransaction transaction) async {
    final bool inserted = await repository.AddManualTransaction(transaction);
    if (inserted) {
      await ReloadHoldings();
      await repository.quote_scheduler.PollQuotesNow();
      await ReloadPortfolioHistory();
    }
    return inserted;
  }

  /// 代號搜尋（手動記帳自動完成）。
  Future<List<SymbolSearchResult>> SearchSymbols(String query) {
    return repository.SearchSymbols(query);
  }

  /// 查單一代號現價（表單預帶價格用），失敗回傳 null。
  Future<double?> FetchCurrentPriceForSymbol(String symbol) async {
    final StockQuote? quote = await repository.FetchSingleQuote(symbol);
    final (double?, String) resolved =
        ResolveDisplayPrice(quote, current_session);
    return resolved.$1 ?? quote?.previous_close;
  }

  /// 切換資產曲線的時間範圍。
  void SwitchCurveRange(CurveRange range) {
    curve_range = range;
    notifyListeners();
  }

  /*
   *  @fn      Future<void> ToggleBenchmark(String index_symbol)
   *
   *  @brief   ( 勾選/取消大盤指數比較；首次勾選時抓取該指數歷史收盤 )
   *
   *  @param   index_symbol - 指數代號（^GSPC / ^IXIC / ^TWII）
   */
  Future<void> ToggleBenchmark(String index_symbol) async {
    if (selected_benchmarks.contains(index_symbol)) {
      selected_benchmarks.remove(index_symbol);
      notifyListeners();
      return;
    }
    selected_benchmarks.add(index_symbol);
    if (!benchmark_closes.containsKey(index_symbol) && history.isNotEmpty) {
      is_benchmark_loading = true;
      notifyListeners();
      try {
        benchmark_closes[index_symbol] = await repository.GetBenchmarkCloses(
            index_symbol, history.first.date);
      } finally {
        is_benchmark_loading = false;
      }
    }
    notifyListeners();
  }

  /// 目前時間範圍內的每日快照（第一筆為期間基準日）。
  List<PortfolioSnapshot> GetVisibleHistory() {
    if (history.isEmpty) {
      return history;
    }
    final int from_date = ResolveRangeStartDate(curve_range, DateTime.now());
    final int start_index =
        history.indexWhere((PortfolioSnapshot s) => s.date >= from_date);
    if (start_index <= 0) {
      return history;
    }
    return history.sublist(start_index);
  }

  /// 目前範圍的期間損益（扣除期間淨投入）。
  double get period_pnl =>
      repository.calculator.CalculatePeriodPnl(GetVisibleHistory());

  /// 目前範圍的累計時間加權報酬率 %（期末值）。
  double get period_return_percent {
    final List<double> series = repository.calculator
        .CalculateCumulativeReturnPercentSeries(GetVisibleHistory());
    return series.isEmpty ? 0 : series.last;
  }

  /// 組合在目前範圍的每日累計報酬率 %（比較模式的曲線資料）。
  List<double> BuildPortfolioReturnPercentSeries() {
    return repository.calculator
        .CalculateCumulativeReturnPercentSeries(GetVisibleHistory());
  }

  /// 指定指數在目前範圍、對齊組合日期的累計報酬率 %。
  List<double?> BuildBenchmarkReturnPercentSeries(String index_symbol) {
    final List<int> dates = GetVisibleHistory()
        .map((PortfolioSnapshot s) => s.date)
        .toList();
    return PortfolioCalculator.BuildBenchmarkReturnPercentSeries(
        benchmark_closes[index_symbol] ?? <int, double>{}, dates);
  }

  /// 依時間範圍算出起始日期（yyyyMMdd）。
  static int ResolveRangeStartDate(CurveRange range, DateTime now) {
    DateTime from;
    switch (range) {
      case CurveRange.one_month:
        from = DateTime(now.year, now.month - 1, now.day);
      case CurveRange.three_months:
        from = DateTime(now.year, now.month - 3, now.day);
      case CurveRange.six_months:
        from = DateTime(now.year, now.month - 6, now.day);
      case CurveRange.year_to_date:
        from = DateTime(now.year, 1, 1);
      case CurveRange.one_year:
        from = DateTime(now.year - 1, now.month, now.day);
      case CurveRange.two_years:
        from = DateTime(now.year - 2, now.month, now.day);
      case CurveRange.all:
        return 0;
    }
    return from.year * 10000 + from.month * 100 + from.day;
  }

  /// 切換漲跌配色慣例並持久化。
  Future<void> SwitchProfitColorConvention(
      ProfitColorConvention convention) async {
    color_convention = convention;
    notifyListeners();
    await settings_store.SaveSetting(SETTING_KEY_COLOR_CONVENTION,
        FormatProfitColorConvention(convention));
  }

  /// 目前持有（未清倉）的顯示列，依市值由大到小排序。
  List<HoldingDisplayRow> BuildHoldingDisplayRows() {
    final Map<String, StockQuote> quotes =
        repository.quote_scheduler.latest_quotes;
    final List<HoldingDisplayRow> rows = holdings
        .where((HoldingPosition p) => !p.is_closed)
        .map((HoldingPosition position) {
      final StockQuote? quote = quotes[position.symbol];
      final (double?, String) price_and_label =
          ResolveDisplayPrice(quote, current_session);
      final double? price = price_and_label.$1;
      final double market_value = price != null
          ? position.net_quantity * price
          : position.total_cost_basis;
      final double unrealized = market_value - position.total_cost_basis;
      final double percent = position.total_cost_basis > 0
          ? unrealized / position.total_cost_basis * 100
          : 0;
      return HoldingDisplayRow(
        position: position,
        current_price: price,
        price_source_label: price_and_label.$2,
        market_value: market_value,
        unrealized_pnl: unrealized,
        unrealized_pnl_percent: percent,
      );
    }).toList()
      ..sort((HoldingDisplayRow a, HoldingDisplayRow b) =>
          b.market_value.compareTo(a.market_value));
    return rows;
  }

  /// 已清倉的持倉（只顯示已實現損益）。
  List<HoldingPosition> GetClosedPositions() {
    return holdings.where((HoldingPosition p) => p.is_closed).toList();
  }

  /// 總市值（無報價的個股以成本計）。
  double get total_market_value => BuildHoldingDisplayRows()
      .fold(0.0, (double sum, HoldingDisplayRow r) => sum + r.market_value);

  /// 總投入成本（僅未清倉部位）。
  double get total_cost_basis => holdings
      .where((HoldingPosition p) => !p.is_closed)
      .fold(0.0, (double sum, HoldingPosition p) => sum + p.total_cost_basis);

  /// 未實現損益總額。
  double get total_unrealized_pnl => total_market_value - total_cost_basis;

  /// 未實現損益 %（成本為 0 時回傳 0）。
  double get total_unrealized_pnl_percent =>
      total_cost_basis > 0 ? total_unrealized_pnl / total_cost_basis * 100 : 0;

  /// 已實現損益總額（含已清倉代號）。
  double get total_realized_pnl => holdings.fold(
      0.0, (double sum, HoldingPosition p) => sum + p.realized_pnl);

  /*
   *  @fn      static (double?, String) ResolveDisplayPrice(StockQuote? quote, MarketSession session)
   *
   *  @brief   ( 依目前時段選出要顯示的價格與來源標示 )
   *
   *  @param   quote - 該檔最新報價（可為 null）
   *  @param   session - 目前美股時段
   *
   *  @return  (價格, 來源標示)；無報價時為 (null, '均價')
   *
   *  @note    盤前優先顯示盤前價、盤後優先顯示盤後價，缺值時退回盤中價。
   */
  static (double?, String) ResolveDisplayPrice(
      StockQuote? quote, MarketSession session) {
    if (quote == null) {
      return (null, '均價');
    }
    if (session == MarketSession.premarket && quote.pre_price != null) {
      return (quote.pre_price, '盤前');
    }
    if ((session == MarketSession.postmarket ||
            session == MarketSession.closed) &&
        quote.post_price != null) {
      return (quote.post_price, '盤後');
    }
    if (quote.regular_price != null) {
      return (quote.regular_price, '盤中');
    }
    return (null, '均價');
  }

  /// 報價更新推播轉發給 UI。
  void _OnQuotesUpdated() {
    notifyListeners();
  }

  @override
  void dispose() {
    repository.quote_scheduler.removeListener(_OnQuotesUpdated);
    super.dispose();
  }
}

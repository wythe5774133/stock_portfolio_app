// 儀表板控制器：UI 層的狀態中樞。
// 只透過 PortfolioRepository 取得資料，不直接碰資料庫、網路或計算引擎。

import 'package:flutter/foundation.dart';

import '../database/app_database.dart' show WatchlistSymbol;
import '../logic/market_registry.dart';
import '../logic/portfolio_calculator.dart';
import '../logic/portfolio_repository.dart';
import '../models/holding_position.dart';
import '../models/market_session.dart';
import '../models/portfolio_snapshot.dart';
import '../models/portfolio_risk_metrics.dart';
import '../models/stock_quote.dart';
import '../models/stock_transaction.dart';
import '../models/symbol_search_result.dart';
import '../services/app_settings_store.dart';
import '../services/backup_service.dart';
import '../services/google_drive_sync_service.dart';
import '../services/csv_transaction_importer.dart';
import 'theme/app_theme.dart';
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

/// 解析顯示幣別字串，未知或空值回傳 'USD'。
String ParseDisplayCurrency(String? raw) {
  return raw == 'TWD' ? 'TWD' : 'USD';
}

/// 個股在列表中的顯示資料（現價與損益已算好，widget 只負責呈現）。
class HoldingDisplayRow {
  final HoldingPosition position;
  final MarketInfo market; // 該檔所屬市場與原生幣別資訊
  final double? current_price; // 依時段選出的顯示價格（原生幣別）
  final String price_source_label; // 價格來源標示（盤中/盤前/盤後/收盤/均價）
  final double market_value; // 市值（原生幣別；無報價時以成本代替）
  final double unrealized_pnl; // 未實現損益（原生幣別）
  final double unrealized_pnl_percent; // 未實現損益 %
  final double? day_pnl; // 今日損益（原生幣別；盤中價 vs 昨收；無報價為 null）
  final double? day_change_percent; // 今日漲跌 %
  final double dividend_income; // 累計股息收入（原生幣別）

  const HoldingDisplayRow({
    required this.position,
    required this.market,
    required this.current_price,
    required this.price_source_label,
    required this.market_value,
    required this.unrealized_pnl,
    required this.unrealized_pnl_percent,
    this.day_pnl,
    this.day_change_percent,
    this.dividend_income = 0,
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
  static const String SETTING_KEY_THEME_MODE = 'theme_mode';
  static const String SETTING_KEY_DIVIDEND_TRACKING = 'dividend_tracking';
  static const String SETTING_KEY_LAST_DRIVE_SYNC = 'last_drive_sync_at';
  static const String SETTING_KEY_DISPLAY_CURRENCY = 'display_currency';

  /// 支援的顯示幣別。
  static const String CURRENCY_USD = 'USD';
  static const String CURRENCY_TWD = 'TWD';

  final PortfolioRepository repository;
  final AppSettingsStore settings_store;

  List<HoldingPosition> holdings = <HoldingPosition>[];
  List<PortfolioSnapshot> history = <PortfolioSnapshot>[];
  bool is_loading = true;
  bool is_history_loading = false;
  ProfitColorConvention color_convention = ProfitColorConvention.us;
  AppThemeMode theme_mode = AppThemeMode.system;

  // 顯示幣別（'USD' | 'TWD'）：預設美金。所有聚合金額換算到此幣別後呈現。
  String display_currency = CURRENCY_USD;

  // 股息追蹤開關：預設關閉。
  // 券商若開啟股息再投資（DRIP），股息已以碎股買入形式出現在交易紀錄，
  // 再計股息收入會重複計算，因此由使用者依自身券商設定決定是否開啟。
  bool dividend_tracking_enabled = false;

  // 股息與年化報酬率
  Map<String, double> dividend_income_by_symbol = <String, double>{};
  double? portfolio_xirr; // 資金加權年化報酬率（null = 資料不足）

  // Google Drive 同步狀態
  bool is_drive_syncing = false;
  DateTime? last_drive_sync_at;

  // 自選股追蹤清單
  List<WatchlistSymbol> watchlist = <WatchlistSymbol>[];
  String? selected_watchlist_group; // null = 顯示全部分類

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
   *  @fn      double? get usd_twd_rate
   *
   *  @brief   ( 目前 1 美元兌台幣匯率：優先取即時報價，退回快取 )
   *
   *  @return  匯率；從未取得過（連快取都沒有）時回傳 null
   *
   *  @note    latest_quotes 於排程啟動時已載入資料庫快取，故此來源已涵蓋
   *           「重啟後沿用上次匯率」的情境。
   */
  double? get usd_twd_rate =>
      repository.quote_scheduler.latest_quotes[USD_TWD_FX_SYMBOL]?.regular_price;

  /*
   *  @fn      String get display_currency_effective
   *
   *  @brief   ( 實際生效的顯示幣別：想顯示 TWD 但無匯率時退回 USD )
   *
   *  @return  'USD' | 'TWD'
   *
   *  @note    UI 應以此 getter 決定金額前綴與符號，避免無匯率時算出錯值。
   */
  String get display_currency_effective {
    if (display_currency == CURRENCY_TWD && usd_twd_rate == null) {
      return CURRENCY_USD;
    }
    return display_currency;
  }

  /// 換算金額到目前生效顯示幣別的便捷函式（匯率缺失時退回原值）。
  double ConvertToDisplayCurrency(double value, String from_currency) {
    return PortfolioCalculator.ConvertCurrencyValue(
      value,
      from_currency,
      display_currency_effective,
      usd_twd_rate ?? 0.0,
    );
  }

  /// 判斷指定市場「現在」的交易時段（美股四段制、台股僅盤中／休市）。
  MarketSession SessionForMarket(String market_id) {
    return repository.session_resolver.ResolveSessionForMarket(
      market_id,
      DateTime.now(),
    );
  }

  /*
   *  @fn      Future<void> SwitchDisplayCurrency(String currency)
   *
   *  @brief   ( 切換顯示幣別並持久化，隨即重算聚合值與資產曲線 )
   *
   *  @param   currency - 'USD' | 'TWD'
   *
   *  @return  None
   *
   *  @note    切到 TWD 時立即抓一次報價（含匯率 'TWD=X'）並重建曲線；
   *           repository.display_currency 同步更新以影響追蹤代號集合。
   */
  Future<void> SwitchDisplayCurrency(String currency) async {
    if (currency != CURRENCY_USD && currency != CURRENCY_TWD) {
      return;
    }
    display_currency = currency;
    repository.display_currency = currency;
    notifyListeners();
    await settings_store.SaveSetting(SETTING_KEY_DISPLAY_CURRENCY, currency);
    // 切到 TWD 需要匯率：立即抓一次（追蹤集合已含 'TWD=X'），再重建曲線與 XIRR
    await repository.quote_scheduler.PollQuotesNow();
    await ReloadPortfolioHistory();
    await RefreshDividendsAndXirr();
  }

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
      settings[SETTING_KEY_COLOR_CONVENTION] as String?,
    );
    theme_mode = ParseAppThemeMode(settings[SETTING_KEY_THEME_MODE] as String?);
    dividend_tracking_enabled =
        (settings[SETTING_KEY_DIVIDEND_TRACKING] as bool?) ?? false;
    display_currency = ParseDisplayCurrency(
      settings[SETTING_KEY_DISPLAY_CURRENCY] as String?,
    );
    repository.display_currency = display_currency;

    await ReloadHoldings();
    await ReloadWatchlist();
    is_loading = false;
    notifyListeners();

    await repository.StartBackgroundQuotePolling();
    await ReloadPortfolioHistory();
    await RefreshDividendsAndXirr();
  }

  /// Google 同步是否已登入。
  bool get is_drive_signed_in => repository.drive_sync_service.is_signed_in;

  /// Google 帳號 email。
  String? get drive_account_email =>
      repository.drive_sync_service.account_email;

  /// 互動式 Google 登入並立即同步；回傳是否登入成功。
  Future<bool> SignInToGoogleDrive() async {
    final bool signed_in = await repository.drive_sync_service.SignIn();
    notifyListeners();
    if (signed_in) {
      await SyncWithDrive();
    }
    return signed_in;
  }

  /// 登出 Google 同步。
  Future<void> SignOutGoogleDrive() async {
    await repository.drive_sync_service.SignOut();
    notifyListeners();
  }

  /*
   *  @fn      Future<bool> SyncWithDrive()
   *
   *  @brief   ( 執行一次 Drive 雙向同步；有拉到新資料時刷新全部畫面 )
   *
   *  @return  true 表示本次同步成功
   */
  Future<bool> SyncWithDrive() async {
    if (!is_drive_signed_in || is_drive_syncing) {
      return false;
    }
    is_drive_syncing = true;
    notifyListeners();
    try {
      final Map<String, dynamic> settings = await settings_store.LoadSettings();
      final DriveSyncResult? result = await repository.drive_sync_service
          .SyncNow(settings);
      if (result == null) {
        return false;
      }
      last_drive_sync_at = result.synced_at;
      await settings_store.SaveSetting(
        SETTING_KEY_LAST_DRIVE_SYNC,
        result.synced_at.millisecondsSinceEpoch,
      );
      if (result.pulled_transactions > 0) {
        // 有從雲端合併進新資料 → 全面刷新
        await ReloadHoldings();
        await ReloadWatchlist();
        await repository.quote_scheduler.PollQuotesNow();
        await ReloadPortfolioHistory();
        await RefreshDividendsAndXirr();
      } else {
        await ReloadWatchlist(); // 追蹤清單/分類可能有變
      }
      return true;
    } finally {
      is_drive_syncing = false;
      notifyListeners();
    }
  }

  /// 重新計算股息收入與 XIRR（匯入、記帳後也會呼叫）。
  /// 股息追蹤關閉時不抓配息資料，XIRR 也不含股息（避免 DRIP 重複計算）。
  Future<void> RefreshDividendsAndXirr() async {
    dividend_income_by_symbol = dividend_tracking_enabled
        ? await repository.GetDividendIncomeBySymbol()
        : <String, double>{};
    portfolio_xirr = await repository.CalculatePortfolioXirr(
      total_market_value,
      dividend_income_by_symbol,
      usd_twd_rate: usd_twd_rate,
    );
    notifyListeners();
  }

  /// 切換股息追蹤開關並持久化，隨即重算股息與 XIRR。
  Future<void> SwitchDividendTracking(bool enabled) async {
    dividend_tracking_enabled = enabled;
    notifyListeners();
    await settings_store.SaveSetting(SETTING_KEY_DIVIDEND_TRACKING, enabled);
    await RefreshDividendsAndXirr();
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
  Future<ImportSummary> ImportCsvContent(
    String csv_content, {
    CsvColumnMapping? column_mapping,
  }) async {
    final ImportSummary summary = await repository.ImportTransactionsFromCsv(
      csv_content,
      column_mapping: column_mapping,
    );
    await ReloadHoldings();
    // 匯入後立即抓一次新持倉的報價，並重建資產曲線與股息統計
    await repository.quote_scheduler.PollQuotesNow();
    await ReloadPortfolioHistory();
    await RefreshDividendsAndXirr();
    return summary;
  }

  /// 讀取 CSV 標題列，供匯入前欄位對應使用。
  List<String> GetCsvHeaders(String csv_content) {
    return repository.csv_importer.GetCsvHeaders(csv_content);
  }

  /// 自動判斷常見券商 CSV 的欄位名稱。
  CsvColumnMapping SuggestCsvColumnMapping(List<String> headers) {
    return repository.csv_importer.SuggestColumnMapping(headers);
  }

  /// 只解析不寫入，供確認畫面顯示預覽與錯誤列。
  CsvParseResult PreviewCsvContent(
    String csv_content,
    CsvColumnMapping column_mapping,
  ) {
    return repository.csv_importer.ParseCsvTransactions(
      csv_content,
      column_mapping: column_mapping,
    );
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
      await RefreshDividendsAndXirr();
    }
    return inserted;
  }

  /// 重新載入追蹤清單。
  Future<void> ReloadWatchlist() async {
    watchlist = await repository.GetWatchlist();
    notifyListeners();
  }

  /// 加入自選追蹤並立即抓報價；回傳 false 表示已在清單中。
  Future<bool> AddToWatchlist(
    String symbol,
    String name, {
    String group_name = '自選',
  }) async {
    final bool added = await repository.AddToWatchlist(
      symbol,
      name,
      group_name: group_name,
    );
    if (added) {
      await ReloadWatchlist();
      await repository.quote_scheduler.PollQuotesNow();
    }
    return added;
  }

  /// 移除自選追蹤。
  Future<void> RemoveFromWatchlist(String symbol) async {
    await repository.RemoveFromWatchlist(symbol);
    await ReloadWatchlist();
  }

  /// 更改追蹤股分類。
  Future<void> ChangeWatchlistGroup(String symbol, String group_name) async {
    await repository.UpdateWatchlistGroup(symbol, group_name);
    await ReloadWatchlist();
  }

  /// 目前存在的分類清單（依加入順序去重）。
  List<String> GetWatchlistGroups() {
    final List<String> groups = <String>[];
    for (final WatchlistSymbol entry in watchlist) {
      if (!groups.contains(entry.group_name)) {
        groups.add(entry.group_name);
      }
    }
    return groups;
  }

  /// 依目前選擇的分類過濾追蹤清單。
  List<WatchlistSymbol> GetFilteredWatchlist() {
    if (selected_watchlist_group == null) {
      return watchlist;
    }
    return watchlist
        .where((WatchlistSymbol w) => w.group_name == selected_watchlist_group)
        .toList();
  }

  /// 切換顯示的分類（null = 全部）。
  void SwitchWatchlistGroup(String? group_name) {
    selected_watchlist_group = group_name;
    notifyListeners();
  }

  /// 匯出備份 JSON（交易＋追蹤清單＋設定）。
  Future<String> ExportBackupJson() async {
    final Map<String, dynamic> settings = await settings_store.LoadSettings();
    return repository.backup_service.BuildBackupJson(settings);
  }

  /*
   *  @fn      Future<BackupRestoreSummary> ImportBackupJson(String backup_json)
   *
   *  @brief   ( 匯入備份並合併：交易去重、追蹤取聯集、設定套用備份值 )
   *
   *  @return  合併統計；格式不符會拋出 FormatException 由 UI 顯示
   */
  Future<BackupRestoreSummary> ImportBackupJson(String backup_json) async {
    final BackupRestoreSummary summary = await repository.backup_service
        .RestoreFromBackupJson(backup_json);

    // 套用備份內的設定（存在才套用）
    final Map<String, dynamic> settings = summary.settings;
    if (settings.containsKey(SETTING_KEY_COLOR_CONVENTION)) {
      color_convention = ParseProfitColorConvention(
        settings[SETTING_KEY_COLOR_CONVENTION] as String?,
      );
      await settings_store.SaveSetting(
        SETTING_KEY_COLOR_CONVENTION,
        settings[SETTING_KEY_COLOR_CONVENTION],
      );
    }
    if (settings.containsKey(SETTING_KEY_THEME_MODE)) {
      theme_mode = ParseAppThemeMode(
        settings[SETTING_KEY_THEME_MODE] as String?,
      );
      await settings_store.SaveSetting(
        SETTING_KEY_THEME_MODE,
        settings[SETTING_KEY_THEME_MODE],
      );
    }
    if (settings.containsKey(SETTING_KEY_DIVIDEND_TRACKING)) {
      dividend_tracking_enabled =
          (settings[SETTING_KEY_DIVIDEND_TRACKING] as bool?) ?? false;
      await settings_store.SaveSetting(
        SETTING_KEY_DIVIDEND_TRACKING,
        settings[SETTING_KEY_DIVIDEND_TRACKING],
      );
    }
    if (settings.containsKey(SETTING_KEY_DISPLAY_CURRENCY)) {
      display_currency = ParseDisplayCurrency(
        settings[SETTING_KEY_DISPLAY_CURRENCY] as String?,
      );
      repository.display_currency = display_currency;
      await settings_store.SaveSetting(
        SETTING_KEY_DISPLAY_CURRENCY,
        display_currency,
      );
    }

    await ReloadHoldings();
    await ReloadWatchlist();
    await repository.quote_scheduler.PollQuotesNow();
    await ReloadPortfolioHistory();
    await RefreshDividendsAndXirr();
    return summary;
  }

  /// 切換深淺主題並持久化。
  Future<void> SwitchAppThemeMode(AppThemeMode mode) async {
    theme_mode = mode;
    notifyListeners();
    await settings_store.SaveSetting(
      SETTING_KEY_THEME_MODE,
      FormatAppThemeMode(mode),
    );
  }

  /// 刪除單筆交易並刷新持倉、曲線與股息統計。
  Future<void> DeleteTransaction(StockTransaction transaction) async {
    await repository.DeleteTransaction(transaction);
    await ReloadHoldings();
    await ReloadPortfolioHistory();
    await RefreshDividendsAndXirr();
  }

  /// 代號搜尋（手動記帳自動完成）。
  Future<List<SymbolSearchResult>> SearchSymbols(String query) {
    return repository.SearchSymbols(query);
  }

  /// 查單一代號現價（表單預帶價格用），失敗回傳 null。
  Future<double?> FetchCurrentPriceForSymbol(String symbol) async {
    final StockQuote? quote = await repository.FetchSingleQuote(symbol);
    final MarketInfo market = ResolveMarketForSymbol(symbol);
    final (double?, String) resolved = ResolveDisplayPrice(
      quote,
      SessionForMarket(market.market_id),
      market,
    );
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
          index_symbol,
          history.first.date,
        );
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
    final int start_index = history.indexWhere(
      (PortfolioSnapshot s) => s.date >= from_date,
    );
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

  /// 依目前可見時間範圍與持倉市值產生風險摘要。
  /// 集中度以「換算後市值」計算，混幣別時佔比才正確。
  PortfolioRiskMetrics get portfolio_risk_metrics {
    final Map<String, double> market_values = <String, double>{
      for (final HoldingDisplayRow row in BuildHoldingDisplayRows())
        if (!row.position.is_closed)
          row.position.symbol: ConvertToDisplayCurrency(
            row.market_value,
            row.market.currency,
          ),
    };
    return repository.calculator.CalculatePortfolioRiskMetrics(
      GetVisibleHistory(),
      market_values,
    );
  }

  /// 組合在目前範圍的每日累計報酬率 %（比較模式的曲線資料）。
  List<double> BuildPortfolioReturnPercentSeries() {
    return repository.calculator.CalculateCumulativeReturnPercentSeries(
      GetVisibleHistory(),
    );
  }

  /// 指定指數在目前範圍、對齊組合日期的累計報酬率 %。
  List<double?> BuildBenchmarkReturnPercentSeries(String index_symbol) {
    final List<int> dates = GetVisibleHistory()
        .map((PortfolioSnapshot s) => s.date)
        .toList();
    return PortfolioCalculator.BuildBenchmarkReturnPercentSeries(
      benchmark_closes[index_symbol] ?? <int, double>{},
      dates,
    );
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
    ProfitColorConvention convention,
  ) async {
    color_convention = convention;
    notifyListeners();
    await settings_store.SaveSetting(
      SETTING_KEY_COLOR_CONVENTION,
      FormatProfitColorConvention(convention),
    );
  }

  /// 目前持有（未清倉）的顯示列，依市值由大到小排序。
  List<HoldingDisplayRow> BuildHoldingDisplayRows() {
    final Map<String, StockQuote> quotes =
        repository.quote_scheduler.latest_quotes;
    final List<HoldingDisplayRow> rows =
        holdings.where((HoldingPosition p) => !p.is_closed).map((
          HoldingPosition position,
        ) {
          final MarketInfo market = ResolveMarketForSymbol(position.symbol);
          final StockQuote? quote = quotes[position.symbol];
          final (double?, String) price_and_label = ResolveDisplayPrice(
            quote,
            SessionForMarket(market.market_id),
            market,
          );
          final double? price = price_and_label.$1;
          final double market_value = price != null
              ? position.net_quantity * price
              : position.total_cost_basis;
          final double unrealized = market_value - position.total_cost_basis;
          final double percent = position.total_cost_basis > 0
              ? unrealized / position.total_cost_basis * 100
              : 0;
          // 今日損益以「盤中價 vs 昨收」計算（延長時段的變動另由價格來源標示呈現）
          double? day_pnl;
          double? day_change_percent;
          if (quote?.regular_price != null && quote?.previous_close != null) {
            final double change = quote!.regular_price! - quote.previous_close!;
            day_pnl = change * position.net_quantity;
            day_change_percent = quote.previous_close! > 0
                ? change / quote.previous_close! * 100
                : null;
          }
          return HoldingDisplayRow(
            position: position,
            market: market,
            current_price: price,
            price_source_label: price_and_label.$2,
            market_value: market_value,
            unrealized_pnl: unrealized,
            unrealized_pnl_percent: percent,
            day_pnl: day_pnl,
            day_change_percent: day_change_percent,
            dividend_income: dividend_income_by_symbol[position.symbol] ?? 0,
          );
        }).toList()..sort(
          // 依「換算後市值」由大到小排序，避免混幣別時被面額大小誤導
          (HoldingDisplayRow a, HoldingDisplayRow b) =>
              ConvertToDisplayCurrency(b.market_value, b.market.currency)
                  .compareTo(
                    ConvertToDisplayCurrency(a.market_value, a.market.currency),
                  ),
        );
    return rows;
  }

  /// 已清倉的持倉（只顯示已實現損益）。
  List<HoldingPosition> GetClosedPositions() {
    return holdings.where((HoldingPosition p) => p.is_closed).toList();
  }

  /// 總市值（無報價的個股以成本計；各檔換算到生效顯示幣別後加總）。
  double get total_market_value => BuildHoldingDisplayRows().fold(
    0.0,
    (double sum, HoldingDisplayRow r) =>
        sum + ConvertToDisplayCurrency(r.market_value, r.market.currency),
  );

  /// 總投入成本（僅未清倉部位；各檔換算到生效顯示幣別後加總）。
  double get total_cost_basis => holdings
      .where((HoldingPosition p) => !p.is_closed)
      .fold(
        0.0,
        (double sum, HoldingPosition p) =>
            sum +
            ConvertToDisplayCurrency(
              p.total_cost_basis,
              ResolveMarketForSymbol(p.symbol).currency,
            ),
      );

  /// 未實現損益總額。
  double get total_unrealized_pnl => total_market_value - total_cost_basis;

  /// 未實現損益 %（成本為 0 時回傳 0）。
  double get total_unrealized_pnl_percent =>
      total_cost_basis > 0 ? total_unrealized_pnl / total_cost_basis * 100 : 0;

  /// 已實現損益總額（含已清倉代號；各檔換算到生效顯示幣別後加總）。
  double get total_realized_pnl => holdings.fold(
    0.0,
    (double sum, HoldingPosition p) =>
        sum +
        ConvertToDisplayCurrency(
          p.realized_pnl,
          ResolveMarketForSymbol(p.symbol).currency,
        ),
  );

  /// 今日損益總額（有報價的持倉換算後加總）。
  double get total_day_pnl => BuildHoldingDisplayRows().fold(
    0.0,
    (double sum, HoldingDisplayRow r) =>
        sum + ConvertToDisplayCurrency(r.day_pnl ?? 0, r.market.currency),
  );

  /// 今日損益 %（相對昨日總市值）。
  double get total_day_change_percent {
    final double day_pnl = total_day_pnl;
    final double yesterday_value = total_market_value - day_pnl;
    return yesterday_value > 0 ? day_pnl / yesterday_value * 100 : 0;
  }

  /// 累計股息收入總額（各檔換算到生效顯示幣別後加總）。
  double get total_dividend_income => dividend_income_by_symbol.entries.fold(
    0.0,
    (double sum, MapEntry<String, double> e) =>
        sum + ConvertToDisplayCurrency(e.value, ResolveMarketForSymbol(e.key).currency),
  );

  /*
   *  @fn      static (double?, String) ResolveDisplayPrice(StockQuote? quote, MarketSession session, MarketInfo market)
   *
   *  @brief   ( 依市場與時段選出要顯示的價格與來源標示 )
   *
   *  @param   quote - 該檔最新報價（可為 null）
   *  @param   session - 該檔所屬市場的目前時段
   *  @param   market - 該檔市場資訊（決定是否有盤前盤後）
   *
   *  @return  (價格, 來源標示)；無報價時為 (null, '均價')
   *
   *  @note    美股：盤前優先盤前價、盤後優先盤後價，缺值退回盤中價。
   *           台股無盤前盤後，永遠用盤中價，標籤依時段為「盤中」或「收盤」。
   */
  static (double?, String) ResolveDisplayPrice(
    StockQuote? quote,
    MarketSession session,
    MarketInfo market,
  ) {
    if (quote == null) {
      return (null, '均價');
    }
    // 台股：只有盤中價，依時段標示盤中／收盤，不出現盤前盤後
    if (market.market_id == 'tw') {
      if (quote.regular_price != null) {
        return (
          quote.regular_price,
          session == MarketSession.regular ? '盤中' : '收盤',
        );
      }
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

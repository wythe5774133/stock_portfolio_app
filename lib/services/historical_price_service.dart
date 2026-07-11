// 歷史日線收盤價服務：以 v8/finance/chart 端點抓取日線並增量快取進 SQLite。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import '../database/historical_price_dao.dart';
import 'market_session_resolver.dart';
import 'yahoo_quote_service.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HistoricalPriceService
 *
 * @brief   抓取指定代號的歷史日收盤價，只補快取缺少的日期區間。
 *
 * @note    Yahoo 日線 K 棒的時間戳為美東開盤時間，
 *          轉換日期時必須用 America/New_York 時區，避免跨日誤差。
 *          抓取失敗（含 429）靜默略過，資產曲線改用既有快取。
 */
class HistoricalPriceService {
  final http.Client http_client;
  final HistoricalPriceDao historical_price_dao;

  HistoricalPriceService({
    required this.historical_price_dao,
    http.Client? http_client,
  }) : http_client = http_client ?? http.Client();

  /*
   *  @fn      Future<void> SyncHistoricalCloses(String symbol, int from_date)
   *
   *  @brief   ( 同步單一代號的日收盤價快取：只抓快取最後一天之後的區間 )
   *
   *  @param   symbol - 股票代號
   *  @param   from_date - 需要的最早日期（yyyyMMdd，通常為該檔最早交易日）
   *
   *  @return  None（結果直接寫入資料庫）
   *
   *  @note    快取已涵蓋到今天則不發出網路請求；失敗不拋例外。
   */
  Future<void> SyncHistoricalCloses(String symbol, int from_date) async {
    MarketSessionResolver.InitializeTimeZoneDatabase();

    final int? latest_cached =
        await historical_price_dao.GetLatestCachedDate(symbol);
    final int today = _FormatDateAsYyyymmdd(DateTime.now());

    int fetch_from = from_date;
    if (latest_cached != null && latest_cached >= from_date) {
      if (latest_cached >= today) {
        return; // 快取已是最新
      }
      fetch_from = latest_cached; // 從快取最後一天重抓一次（涵蓋當日修正）
    }

    final Map<int, double>? closes =
        await FetchDailyCloses(symbol, fetch_from, today);
    if (closes != null && closes.isNotEmpty) {
      await historical_price_dao.SaveHistoricalCloses(symbol, closes);
    }
  }

  /*
   *  @fn      Future<Map<int, double>?> FetchDailyCloses(String symbol, int from_date, int to_date)
   *
   *  @brief   ( 從 Yahoo chart 端點抓取日線收盤價 )
   *
   *  @param   symbol - 股票代號
   *  @param   from_date / to_date - 起訖日期（yyyyMMdd，含端點）
   *
   *  @return  {yyyyMMdd: close}；請求失敗回傳 null
   *
   *  @note    query1 被限流時自動改用 query2；null 收盤價（停牌日）跳過。
   */
  Future<Map<int, double>?> FetchDailyCloses(
      String symbol, int from_date, int to_date) async {
    final int period1 = _ConvertYyyymmddToEpochSeconds(from_date);
    // period2 取隔日 00:00，確保含 to_date 當天
    final int period2 = _ConvertYyyymmddToEpochSeconds(to_date) + 86400;

    for (final String host in YahooQuoteService.QUERY_HOSTS) {
      final Uri uri =
          Uri.https(host, '/v8/finance/chart/$symbol', <String, String>{
        'period1': '$period1',
        'period2': '$period2',
        'interval': '1d',
      });
      try {
        final http.Response response = await http_client.get(uri,
            headers: <String, String>{
              'User-Agent': YahooQuoteService.USER_AGENT,
            }).timeout(YahooQuoteService.REQUEST_TIMEOUT);
        if (response.statusCode == 429) {
          continue; // 換備援主機
        }
        if (response.statusCode != 200) {
          return null;
        }
        return ParseChartHistoryJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  /*
   *  @fn      static Map<int, double> ParseChartHistoryJson(Map<String, dynamic> json)
   *
   *  @brief   ( 解析 chart 日線回應為 {yyyyMMdd: 收盤價} )
   *
   *  @param   json - chart 端點完整回應 JSON
   *
   *  @return  日期對收盤價的 map；格式不符回傳空 map
   *
   *  @note    純函式，單元測試以 fixture JSON 驗證；
   *           時間戳以美東時區換算日期。
   */
  static Map<int, double> ParseChartHistoryJson(Map<String, dynamic> json) {
    MarketSessionResolver.InitializeTimeZoneDatabase();
    final tz.Location new_york = tz.getLocation('America/New_York');

    final Map<int, double> closes_by_date = <int, double>{};
    final List<dynamic>? results =
        (json['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return closes_by_date;
    }
    final Map<String, dynamic> result = results.first as Map<String, dynamic>;
    final List<dynamic>? timestamps = result['timestamp'] as List<dynamic>?;
    final List<dynamic>? closes =
        (((result['indicators'] as Map<String, dynamic>?)?['quote']
                as List<dynamic>?)
            ?.firstOrNull as Map<String, dynamic>?)?['close'] as List<dynamic>?;
    if (timestamps == null || closes == null) {
      return closes_by_date;
    }

    for (int i = 0; i < timestamps.length && i < closes.length; i++) {
      final dynamic close_raw = closes[i];
      if (close_raw is! num) {
        continue; // 停牌或缺值
      }
      final int epoch_seconds = (timestamps[i] as num).toInt();
      final tz.TZDateTime new_york_time = tz.TZDateTime.fromMillisecondsSinceEpoch(
          new_york, epoch_seconds * 1000);
      final int date = new_york_time.year * 10000 +
          new_york_time.month * 100 +
          new_york_time.day;
      closes_by_date[date] = close_raw.toDouble();
    }
    return closes_by_date;
  }

  /// yyyyMMdd 轉美東時區當日 00:00 的 epoch 秒。
  static int _ConvertYyyymmddToEpochSeconds(int yyyymmdd) {
    MarketSessionResolver.InitializeTimeZoneDatabase();
    final tz.Location new_york = tz.getLocation('America/New_York');
    final tz.TZDateTime moment = tz.TZDateTime(
        new_york, yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100);
    return moment.millisecondsSinceEpoch ~/ 1000;
  }

  /// DateTime 轉 yyyyMMdd 整數（本地時間）。
  static int _FormatDateAsYyyymmdd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}

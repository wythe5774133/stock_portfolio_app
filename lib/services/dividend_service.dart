// 配息事件服務：以 Yahoo chart 端點（events=div）抓取歷史配息並快取。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import '../database/dividend_dao.dart';
import 'market_session_resolver.dart';
import 'yahoo_quote_service.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   DividendService
 *
 * @brief   抓取指定代號的歷史配息事件（除息日＋每股金額）並存入本地快取。
 *
 * @note    配息一季至多一次，因此每個 App 執行階段每檔只抓一次全區間；
 *          失敗（含 429）靜默略過，使用既有快取。
 */
class DividendService {
  final http.Client http_client;
  final DividendDao dividend_dao;

  /// 本執行階段已同步過的代號（避免重複請求）
  final Set<String> _synced_symbols = <String>{};

  DividendService({
    required this.dividend_dao,
    http.Client? http_client,
  }) : http_client = http_client ?? http.Client();

  /*
   *  @fn      Future<void> SyncDividendEvents(String symbol, int from_date)
   *
   *  @brief   ( 同步單一代號的配息事件：每個執行階段每檔抓一次全區間 )
   *
   *  @param   symbol - 股票代號
   *  @param   from_date - 需要的最早日期（yyyyMMdd，通常為最早交易日）
   *
   *  @return  None（結果直接寫入資料庫）
   */
  Future<void> SyncDividendEvents(String symbol, int from_date) async {
    if (_synced_symbols.contains(symbol)) {
      return;
    }
    final Map<int, double>? dividends =
        await FetchDividendEvents(symbol, from_date);
    if (dividends != null) {
      _synced_symbols.add(symbol);
      if (dividends.isNotEmpty) {
        await dividend_dao.SaveDividendEvents(symbol, dividends);
      }
    }
  }

  /*
   *  @fn      Future<Map<int, double>?> FetchDividendEvents(String symbol, int from_date)
   *
   *  @brief   ( 從 Yahoo chart 端點抓取配息事件 )
   *
   *  @param   symbol - 股票代號
   *  @param   from_date - 起始日期（yyyyMMdd）
   *
   *  @return  {除息日: 每股金額}；請求失敗回傳 null
   */
  Future<Map<int, double>?> FetchDividendEvents(
      String symbol, int from_date) async {
    MarketSessionResolver.InitializeTimeZoneDatabase();
    final tz.Location new_york = tz.getLocation('America/New_York');
    final int period1 = tz.TZDateTime(new_york, from_date ~/ 10000,
                (from_date ~/ 100) % 100, from_date % 100)
            .millisecondsSinceEpoch ~/
        1000;
    final int period2 =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 86400;

    for (final String host in YahooQuoteService.QUERY_HOSTS) {
      final Uri uri =
          Uri.https(host, '/v8/finance/chart/$symbol', <String, String>{
        'period1': '$period1',
        'period2': '$period2',
        'interval': '1d',
        'events': 'div',
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
        return ParseDividendEventsJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  /*
   *  @fn      static Map<int, double> ParseDividendEventsJson(Map<String, dynamic> json)
   *
   *  @brief   ( 解析 chart 回應中的 events.dividends 為 {除息日: 每股金額} )
   *
   *  @param   json - chart 端點完整回應
   *
   *  @return  配息事件 map；無配息或格式不符回傳空 map（純函式，供單元測試）
   */
  static Map<int, double> ParseDividendEventsJson(Map<String, dynamic> json) {
    MarketSessionResolver.InitializeTimeZoneDatabase();
    final tz.Location new_york = tz.getLocation('America/New_York');

    final Map<int, double> dividends_by_date = <int, double>{};
    final List<dynamic>? results =
        (json['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return dividends_by_date;
    }
    final Map<String, dynamic>? raw_dividends =
        ((results.first as Map<String, dynamic>)['events']
            as Map<String, dynamic>?)?['dividends'] as Map<String, dynamic>?;
    if (raw_dividends == null) {
      return dividends_by_date;
    }

    for (final dynamic raw in raw_dividends.values) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final num? amount = raw['amount'] as num?;
      final num? epoch_seconds = raw['date'] as num?;
      if (amount == null || epoch_seconds == null) {
        continue;
      }
      final tz.TZDateTime new_york_time = tz.TZDateTime.fromMillisecondsSinceEpoch(
          new_york, epoch_seconds.toInt() * 1000);
      final int ex_date = new_york_time.year * 10000 +
          new_york_time.month * 100 +
          new_york_time.day;
      dividends_by_date[ex_date] = amount.toDouble();
    }
    return dividends_by_date;
  }
}

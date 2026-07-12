// Yahoo Finance 即時報價服務（非官方端點，免 API Key）。
// 主路徑：cookie + crumb 後呼叫 v7/finance/quote 批量查詢。
// 備援路徑：v8/finance/chart?includePrePost=true 逐檔查詢。
// 所有失敗（含 429 限流）都不會向外拋出例外，改以退避與空結果處理。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/market_session.dart';
import '../models/stock_quote.dart';
import 'market_session_resolver.dart';
import 'yahoo_endpoints.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   YahooQuoteService
 *
 * @brief   透過 Yahoo Finance 非官方端點抓取盤前/盤中/盤後即時報價。
 *
 * @note    Yahoo 對頻繁請求會回 429，本服務內建指數退避
 *          （30s → 60s → 120s → 300s 上限），退避期間直接回傳空結果，
 *          由呼叫端沿用資料庫快取顯示。
 */
class YahooQuoteService {
  static const String USER_AGENT =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0 Safari/537.36';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 10);
  static const List<String> QUERY_HOSTS = <String>[
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
  ];

  final http.Client http_client;
  final MarketSessionResolver session_resolver;

  String? _cookie_header; // 已取得的 cookie（Cookie 標頭值）
  String? _crumb; // 已取得的 crumb
  int _consecutive_failures = 0; // 連續失敗次數（退避用）
  DateTime? _backoff_until; // 退避截止時間

  YahooQuoteService({
    http.Client? http_client,
    MarketSessionResolver? session_resolver,
  })  : http_client = http_client ?? http.Client(),
        session_resolver = session_resolver ?? MarketSessionResolver();

  /// 目前是否處於退避期間（測試與 UI 顯示用）。
  bool get is_backing_off =>
      _backoff_until != null && DateTime.now().isBefore(_backoff_until!);

  /*
   *  @fn      Future<Map<String, StockQuote>> FetchRealtimeQuotes(List<String> symbols)
   *
   *  @brief   ( 抓取多檔股票的即時報價，主路徑失敗自動走備援 )
   *
   *  @param   symbols - 股票代號清單
   *
   *  @return  {symbol: StockQuote}；失敗或退避期間回傳空 map（部分成功回傳部分）
   *
   *  @note    絕不向外拋例外；呼叫端以空結果代表「暫時無法取得報價」。
   */
  Future<Map<String, StockQuote>> FetchRealtimeQuotes(
      List<String> symbols) async {
    if (symbols.isEmpty || is_backing_off) {
      return <String, StockQuote>{};
    }
    // 網頁版跳過 v7（cookie+crumb 流程跨網域不可行），直接走 chart 備援
    if (!kIsWeb) {
      try {
        final Map<String, StockQuote> via_v7 =
            await _FetchQuotesViaV7(symbols);
        if (via_v7.isNotEmpty) {
          _ResetBackoff();
          return via_v7;
        }
      } catch (_) {
        // 主路徑失敗，走備援
      }
    }

    try {
      final Map<String, StockQuote> via_chart =
          await _FetchQuotesViaChart(symbols);
      if (via_chart.isNotEmpty) {
        _ResetBackoff();
        return via_chart;
      }
    } catch (_) {
      // 備援也失敗
    }

    _RecordFailureAndBackoff();
    return <String, StockQuote>{};
  }

  /// 主路徑：v7/finance/quote 批量查詢（需 cookie + crumb）。
  Future<Map<String, StockQuote>> _FetchQuotesViaV7(
      List<String> symbols) async {
    await _EnsureCookieAndCrumb();
    if (_crumb == null) {
      return <String, StockQuote>{};
    }

    final Uri uri = BuildYahooUri('query1.finance.yahoo.com',
        '/v7/finance/quote', <String, String>{
      'symbols': symbols.join(','),
      'crumb': _crumb!,
    });
    final http.Response response = await http_client.get(uri,
        headers: _BuildRequestHeaders()).timeout(REQUEST_TIMEOUT);

    if (response.statusCode == 401 || response.statusCode == 403) {
      // cookie/crumb 失效，清掉讓下一輪重取
      _cookie_header = null;
      _crumb = null;
      return <String, StockQuote>{};
    }
    if (response.statusCode != 200) {
      return <String, StockQuote>{};
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> results =
        ((body['quoteResponse'] as Map<String, dynamic>?)?['result']
                as List<dynamic>?) ??
            <dynamic>[];

    final DateTime fetched_at = DateTime.now();
    final Map<String, StockQuote> quotes = <String, StockQuote>{};
    for (final dynamic raw in results) {
      final StockQuote quote =
          ParseV7QuoteJson(raw as Map<String, dynamic>, fetched_at);
      quotes[quote.symbol] = quote;
    }
    return quotes;
  }

  /// 備援路徑：v8/finance/chart 逐檔查詢，query1 被限流時改用 query2。
  Future<Map<String, StockQuote>> _FetchQuotesViaChart(
      List<String> symbols) async {
    final Map<String, StockQuote> quotes = <String, StockQuote>{};
    for (final String symbol in symbols) {
      for (final String host in QUERY_HOSTS) {
        final Uri uri = BuildYahooUri(host, '/v8/finance/chart/$symbol',
            <String, String>{
          'range': '1d',
          'interval': '1m',
          'includePrePost': 'true',
        });
        try {
          final http.Response response = await http_client.get(uri,
              headers: _BuildRequestHeaders()).timeout(REQUEST_TIMEOUT);
          if (response.statusCode == 429) {
            continue; // 換下一台主機
          }
          if (response.statusCode != 200) {
            break;
          }
          final StockQuote? quote = ParseChartQuoteJson(
            jsonDecode(response.body) as Map<String, dynamic>,
            DateTime.now(),
            session_resolver,
          );
          if (quote != null) {
            quotes[quote.symbol] = quote;
          }
          break;
        } on Exception {
          break; // 逾時或連線失敗，跳過此檔
        }
      }
    }
    return quotes;
  }

  /// 取得並快取 cookie 與 crumb；失敗時保持 null，不拋例外。
  Future<void> _EnsureCookieAndCrumb() async {
    if (_cookie_header != null && _crumb != null) {
      return;
    }
    try {
      // 步驟 1：向 fc.yahoo.com 要 cookie（回應 404 沒關係，重點是 Set-Cookie）
      final http.Response cookie_response = await http_client
          .get(Uri.https('fc.yahoo.com', '/'),
              headers: BuildYahooHeaders(USER_AGENT))
          .timeout(REQUEST_TIMEOUT);
      final String? set_cookie = cookie_response.headers['set-cookie'];
      if (set_cookie == null || set_cookie.isEmpty) {
        return;
      }
      _cookie_header = ExtractCookiePairs(set_cookie);

      // 步驟 2：帶 cookie 取 crumb
      final http.Response crumb_response = await http_client
          .get(
              BuildYahooUri('query1.finance.yahoo.com', '/v1/test/getcrumb',
                  <String, String>{}),
              headers: _BuildRequestHeaders())
          .timeout(REQUEST_TIMEOUT);
      if (crumb_response.statusCode == 200 &&
          crumb_response.body.isNotEmpty &&
          !crumb_response.body.contains(' ')) {
        _crumb = crumb_response.body.trim();
      }
    } catch (_) {
      // 取 cookie/crumb 失敗，主路徑本輪放棄
    }
  }

  /// 組出帶 User-Agent 與 cookie 的請求標頭（網頁版為空）。
  Map<String, String> _BuildRequestHeaders() {
    return BuildYahooHeaders(USER_AGENT, cookie_header: _cookie_header);
  }

  /// 記錄一次失敗並延長退避時間（30s→60s→120s→300s 上限）。
  void _RecordFailureAndBackoff() {
    _consecutive_failures++;
    final int seconds = 30 * (1 << (_consecutive_failures - 1));
    final int capped_seconds = seconds > 300 ? 300 : seconds;
    _backoff_until = DateTime.now().add(Duration(seconds: capped_seconds));
  }

  /// 成功後重設退避狀態。
  void _ResetBackoff() {
    _consecutive_failures = 0;
    _backoff_until = null;
  }

  /*
   *  @fn      static StockQuote ParseV7QuoteJson(Map<String, dynamic> json, DateTime fetched_at)
   *
   *  @brief   ( 解析 v7/finance/quote 單檔結果 JSON 為 StockQuote )
   *
   *  @param   json - quoteResponse.result[] 中的單一元素
   *  @param   fetched_at - 本地抓取時間
   *
   *  @return  StockQuote - 缺少的價格欄位為 null
   *
   *  @note    純函式，單元測試直接以 fixture JSON 驗證。
   */
  static StockQuote ParseV7QuoteJson(
      Map<String, dynamic> json, DateTime fetched_at) {
    return StockQuote(
      symbol: (json['symbol'] as String?) ?? '',
      regular_price: _ReadDouble(json['regularMarketPrice']),
      regular_time: _ReadInt(json['regularMarketTime']),
      pre_price: _ReadDouble(json['preMarketPrice']),
      pre_time: _ReadInt(json['preMarketTime']),
      post_price: _ReadDouble(json['postMarketPrice']),
      post_time: _ReadInt(json['postMarketTime']),
      previous_close: _ReadDouble(json['regularMarketPreviousClose']),
      fetched_at: fetched_at,
      market_state: json['marketState'] as String?,
      open_price: _ReadDouble(json['regularMarketOpen']),
      day_high: _ReadDouble(json['regularMarketDayHigh']),
      day_low: _ReadDouble(json['regularMarketDayLow']),
      volume: _ReadDouble(json['regularMarketVolume']),
      fifty_two_week_high: _ReadDouble(json['fiftyTwoWeekHigh']),
      fifty_two_week_low: _ReadDouble(json['fiftyTwoWeekLow']),
      market_cap: _ReadDouble(json['marketCap']),
      trailing_pe: _ReadDouble(json['trailingPE']),
    );
  }

  /*
   *  @fn      static StockQuote? ParseChartQuoteJson(Map<String, dynamic> json,
   *               DateTime fetched_at, MarketSessionResolver resolver)
   *
   *  @brief   ( 解析 v8/finance/chart 回應，從 meta 與最後一筆 tick 推出即時報價 )
   *
   *  @param   json - chart 端點完整回應 JSON
   *  @param   fetched_at - 本地抓取時間
   *  @param   resolver - 用來判斷最後一筆 tick 屬於盤前或盤後
   *
   *  @return  StockQuote；回應格式不符時回傳 null
   *
   *  @note    盤前/盤後價由最後一筆非 null tick 的時間戳判斷時段後填入。
   */
  static StockQuote? ParseChartQuoteJson(
    Map<String, dynamic> json,
    DateTime fetched_at,
    MarketSessionResolver resolver,
  ) {
    final List<dynamic>? results =
        (json['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return null;
    }
    final Map<String, dynamic> result = results.first as Map<String, dynamic>;
    final Map<String, dynamic>? meta =
        result['meta'] as Map<String, dynamic>?;
    if (meta == null) {
      return null;
    }

    final String symbol = (meta['symbol'] as String?) ?? '';
    final double? regular_price = _ReadDouble(meta['regularMarketPrice']);
    final int? regular_time = _ReadInt(meta['regularMarketTime']);
    final double? previous_close = _ReadDouble(meta['chartPreviousClose']) ??
        _ReadDouble(meta['previousClose']);

    // 從最後一筆非 null 收盤 tick 推盤前/盤後價
    double? pre_price;
    int? pre_time;
    double? post_price;
    int? post_time;
    final List<dynamic>? timestamps = result['timestamp'] as List<dynamic>?;
    final List<dynamic>? closes =
        (((result['indicators'] as Map<String, dynamic>?)?['quote']
                as List<dynamic>?)
            ?.firstOrNull as Map<String, dynamic>?)?['close'] as List<dynamic>?;
    if (timestamps != null && closes != null) {
      for (int i = timestamps.length - 1; i >= 0; i--) {
        final double? close = _ReadDouble(i < closes.length ? closes[i] : null);
        if (close == null) {
          continue;
        }
        final int tick_time = _ReadInt(timestamps[i])!;
        final MarketSession tick_session = resolver.ResolveMarketSessionAt(
            DateTime.fromMillisecondsSinceEpoch(tick_time * 1000, isUtc: true));
        if (tick_session == MarketSession.premarket) {
          pre_price = close;
          pre_time = tick_time;
        } else if (tick_session == MarketSession.postmarket) {
          post_price = close;
          post_time = tick_time;
        }
        break; // 只需要最後一筆有效 tick
      }
    }

    return StockQuote(
      symbol: symbol,
      regular_price: regular_price,
      regular_time: regular_time,
      pre_price: pre_price,
      pre_time: pre_time,
      post_price: post_price,
      post_time: post_time,
      previous_close: previous_close,
      fetched_at: fetched_at,
      market_state: null,
    );
  }

  /// 從 Set-Cookie 標頭抽出各 cookie 的 name=value 對，組成 Cookie 標頭值。
  /// http 套件會把多個 Set-Cookie 以逗號合併，且 expires 內也含逗號，
  /// 因此以「逗號後跟 token= 」為分隔切開。
  static String ExtractCookiePairs(String set_cookie_header) {
    final List<String> cookie_segments =
        set_cookie_header.split(RegExp(r',(?=\s*[A-Za-z0-9_.\-]+=)'));
    final List<String> pairs = <String>[];
    for (final String segment in cookie_segments) {
      final String first_part = segment.split(';').first.trim();
      if (first_part.contains('=')) {
        pairs.add(first_part);
      }
    }
    return pairs.join('; ');
  }

  /// JSON 數值容錯讀取為 double（Yahoo 偶爾回整數）。
  static double? _ReadDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  /// JSON 數值容錯讀取為 int。
  static int? _ReadInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

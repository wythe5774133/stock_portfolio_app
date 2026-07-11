// 股票代號搜尋服務：Yahoo Finance 搜尋端點（免 API Key），
// 供手動記帳時的代號自動完成使用。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/stock_news_item.dart';
import '../models/symbol_search_result.dart';
import 'yahoo_quote_service.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   StockSymbolSearchService
 *
 * @brief   以關鍵字搜尋股票代號與名稱（美股、台股等 Yahoo 支援的市場皆可）。
 *
 * @note    失敗（含 429）一律回傳空清單，不拋例外；
 *          UI 端搭配輸入去抖動（debounce）避免打字過程狂發請求。
 */
class StockSymbolSearchService {
  /// 只保留可交易的類型（排除新聞、匯率等雜項）
  static const Set<String> TRADABLE_QUOTE_TYPES = <String>{
    'EQUITY',
    'ETF',
    'INDEX',
    'MUTUALFUND',
  };

  final http.Client http_client;

  StockSymbolSearchService({http.Client? http_client})
      : http_client = http_client ?? http.Client();

  /*
   *  @fn      Future<List<SymbolSearchResult>> SearchSymbols(String query)
   *
   *  @brief   ( 以關鍵字搜尋股票，回傳代號+名稱建議清單 )
   *
   *  @param   query - 使用者輸入的關鍵字（代號或公司名稱片段）
   *
   *  @return  最多 8 筆結果；查無或失敗回傳空清單
   */
  Future<List<SymbolSearchResult>> SearchSymbols(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <SymbolSearchResult>[];
    }
    for (final String host in YahooQuoteService.QUERY_HOSTS) {
      final Uri uri = Uri.https(host, '/v1/finance/search', <String, String>{
        'q': trimmed,
        'quotesCount': '8',
        'newsCount': '0',
        'listsCount': '0',
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
          return <SymbolSearchResult>[];
        }
        return ParseSearchResponseJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } on Exception {
        return <SymbolSearchResult>[];
      }
    }
    return <SymbolSearchResult>[];
  }

  /*
   *  @fn      Future<List<StockNewsItem>> FetchNewsForSymbol(String symbol)
   *
   *  @brief   ( 抓取單一股票的相關新聞，供個股詳情頁顯示 )
   *
   *  @param   symbol - 股票代號
   *
   *  @return  最多 8 則新聞；失敗回傳空清單不拋例外
   */
  Future<List<StockNewsItem>> FetchNewsForSymbol(String symbol) async {
    for (final String host in YahooQuoteService.QUERY_HOSTS) {
      final Uri uri = Uri.https(host, '/v1/finance/search', <String, String>{
        'q': symbol,
        'quotesCount': '0',
        'newsCount': '8',
        'listsCount': '0',
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
          return <StockNewsItem>[];
        }
        return ParseNewsResponseJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } on Exception {
        return <StockNewsItem>[];
      }
    }
    return <StockNewsItem>[];
  }

  /*
   *  @fn      static List<StockNewsItem> ParseNewsResponseJson(Map<String, dynamic> json)
   *
   *  @brief   ( 解析搜尋端點回應中的 news 陣列 )
   *
   *  @return  新聞清單，缺標題或連結的項目跳過（純函式，供單元測試）
   */
  static List<StockNewsItem> ParseNewsResponseJson(Map<String, dynamic> json) {
    final List<dynamic>? news = json['news'] as List<dynamic>?;
    if (news == null) {
      return <StockNewsItem>[];
    }
    final List<StockNewsItem> items = <StockNewsItem>[];
    for (final dynamic raw in news) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String? title = raw['title'] as String?;
      final String? link = raw['link'] as String?;
      if (title == null || title.isEmpty || link == null || link.isEmpty) {
        continue;
      }
      final num? publish_time = raw['providerPublishTime'] as num?;
      items.add(StockNewsItem(
        title: title,
        publisher: (raw['publisher'] as String?) ?? '',
        link: link,
        published_at: publish_time != null
            ? DateTime.fromMillisecondsSinceEpoch(publish_time.toInt() * 1000)
            : null,
      ));
    }
    return items;
  }

  /*
   *  @fn      static List<SymbolSearchResult> ParseSearchResponseJson(Map<String, dynamic> json)
   *
   *  @brief   ( 解析搜尋端點回應，過濾出可交易的標的 )
   *
   *  @param   json - 搜尋端點完整回應
   *
   *  @return  過濾排序後的結果清單（純函式，供單元測試）
   */
  static List<SymbolSearchResult> ParseSearchResponseJson(
      Map<String, dynamic> json) {
    final List<dynamic>? quotes = json['quotes'] as List<dynamic>?;
    if (quotes == null) {
      return <SymbolSearchResult>[];
    }
    final List<SymbolSearchResult> results = <SymbolSearchResult>[];
    for (final dynamic raw in quotes) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String? symbol = raw['symbol'] as String?;
      final String quote_type = (raw['quoteType'] as String?) ?? '';
      if (symbol == null ||
          symbol.isEmpty ||
          !TRADABLE_QUOTE_TYPES.contains(quote_type)) {
        continue;
      }
      results.add(SymbolSearchResult(
        symbol: symbol,
        name: (raw['longname'] as String?) ??
            (raw['shortname'] as String?) ??
            symbol,
        exchange: (raw['exchDisp'] as String?) ?? '',
        quote_type: quote_type,
      ));
    }
    return results;
  }
}

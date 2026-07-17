// 股票代號搜尋服務：Yahoo Finance 搜尋端點（免 API Key），
// 供手動記帳時的代號自動完成使用。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/stock_news_item.dart';
import '../models/symbol_search_result.dart';
import 'yahoo_endpoints.dart';
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
      final Uri uri = BuildYahooUri(
        host,
        '/v1/finance/search',
        <String, String>{
          'q': trimmed,
          'quotesCount': '8',
          'newsCount': '0',
          'listsCount': '0',
        },
      );
      try {
        final http.Response response = await http_client
            .get(uri, headers: BuildYahooHeaders(YahooQuoteService.USER_AGENT))
            .timeout(YahooQuoteService.REQUEST_TIMEOUT);
        if (response.statusCode == 429) {
          continue; // 換備援主機
        }
        if (response.statusCode != 200) {
          return <SymbolSearchResult>[];
        }
        return ParseSearchResponseJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
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
  Future<List<StockNewsItem>> FetchNewsForSymbol(
    String symbol, {
    String? display_name,
  }) async {
    final bool is_taiwan_symbol = IsTaiwanSymbol(symbol);
    final String trimmed_name = display_name?.trim() ?? '';
    final String news_query =
        is_taiwan_symbol &&
            trimmed_name.isNotEmpty &&
            trimmed_name.toUpperCase() != symbol.toUpperCase()
        ? trimmed_name
        : symbol;
    for (final String host in YahooQuoteService.QUERY_HOSTS) {
      final Uri uri = BuildYahooUri(
        host,
        '/v1/finance/search',
        <String, String>{
          'q': news_query,
          // 台股代號直接查詢會回傳全站熱門新聞；同時取公司名稱對應標的，
          // 例如 2330.TW 以公司名稱搜尋後會取得美股 ADR 代號 TSM。
          'quotesCount': is_taiwan_symbol ? '1' : '0',
          'newsCount': is_taiwan_symbol ? '20' : '8',
          'listsCount': '0',
        },
      );
      try {
        final http.Response response = await http_client
            .get(uri, headers: BuildYahooHeaders(YahooQuoteService.USER_AGENT))
            .timeout(YahooQuoteService.REQUEST_TIMEOUT);
        if (response.statusCode == 429) {
          continue; // 換備援主機
        }
        if (response.statusCode != 200) {
          return <StockNewsItem>[];
        }
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (!is_taiwan_symbol) {
          return ParseNewsResponseJson(body);
        }
        final Set<String> relevant_symbols = <String>{symbol.toUpperCase()};
        final List<dynamic>? matched_quotes = body['quotes'] as List<dynamic>?;
        if (matched_quotes != null && matched_quotes.isNotEmpty) {
          final dynamic first_quote = matched_quotes.first;
          if (first_quote is Map<String, dynamic>) {
            final String? matched_symbol = first_quote['symbol'] as String?;
            if (matched_symbol != null && matched_symbol.isNotEmpty) {
              relevant_symbols.add(matched_symbol.toUpperCase());
            }
          }
        }
        return ParseNewsResponseJson(
          body,
          relevant_symbols: relevant_symbols,
          relevance_terms: BuildNewsRelevanceTerms(trimmed_name),
        ).take(8).toList();
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
  static List<StockNewsItem> ParseNewsResponseJson(
    Map<String, dynamic> json, {
    Set<String> relevant_symbols = const <String>{},
    Set<String> relevance_terms = const <String>{},
  }) {
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
      if (relevant_symbols.isNotEmpty || relevance_terms.isNotEmpty) {
        final List<dynamic>? raw_related_tickers =
            raw['relatedTickers'] as List<dynamic>?;
        final Set<String> related_tickers = (raw_related_tickers ?? <dynamic>[])
            .whereType<String>()
            .map((String ticker) => ticker.toUpperCase())
            .toSet();
        final bool ticker_matches = related_tickers.any(
          (String ticker) => relevant_symbols.contains(ticker),
        );
        final String normalized_title = title.toLowerCase();
        final bool title_matches = relevance_terms.any(
          (String term) => normalized_title.contains(term),
        );
        if (!ticker_matches && !title_matches) {
          continue;
        }
      }
      final num? publish_time = raw['providerPublishTime'] as num?;
      items.add(
        StockNewsItem(
          title: title,
          publisher: (raw['publisher'] as String?) ?? '',
          link: link,
          published_at: publish_time != null
              ? DateTime.fromMillisecondsSinceEpoch(publish_time.toInt() * 1000)
              : null,
        ),
      );
    }
    return items;
  }

  /// 判斷是否為 Yahoo 台灣上市／上櫃代號。
  static bool IsTaiwanSymbol(String symbol) {
    final String normalized = symbol.trim().toUpperCase();
    return normalized.endsWith('.TW') || normalized.endsWith('.TWO');
  }

  /// 從公司名稱取出可用於新聞標題比對的關鍵詞，排除過度通用的公司字樣。
  static Set<String> BuildNewsRelevanceTerms(String display_name) {
    const Set<String> ignored_terms = <String>{
      'taiwan',
      'company',
      'corporation',
      'limited',
      'holdings',
      'holding',
      'group',
      'inc',
      'ltd',
      'co',
    };
    return display_name
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where(
          (String term) => term.length >= 3 && !ignored_terms.contains(term),
        )
        .toSet();
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
    Map<String, dynamic> json,
  ) {
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
      results.add(
        SymbolSearchResult(
          symbol: symbol,
          name:
              (raw['longname'] as String?) ??
              (raw['shortname'] as String?) ??
              symbol,
          exchange: (raw['exchDisp'] as String?) ?? '',
          quote_type: quote_type,
        ),
      );
    }
    return results;
  }
}

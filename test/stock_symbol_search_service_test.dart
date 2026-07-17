// StockSymbolSearchService 單元測試：搜尋回應解析與失敗處理。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_portfolio_app/models/stock_news_item.dart';
import 'package:stock_portfolio_app/models/symbol_search_result.dart';
import 'package:stock_portfolio_app/services/stock_symbol_search_service.dart';

/// Yahoo 搜尋端點回應 fixture（欄位子集）。
const Map<String, dynamic> SEARCH_RESPONSE_FIXTURE = <String, dynamic>{
  'quotes': <dynamic>[
    <String, dynamic>{
      'symbol': 'NVDA',
      'shortname': 'NVIDIA Corporation',
      'longname': 'NVIDIA Corporation',
      'exchDisp': 'NASDAQ',
      'quoteType': 'EQUITY',
    },
    <String, dynamic>{
      'symbol': '2330.TW',
      'shortname': 'TAIWAN SEMICONDUCTOR MANUFACTUR',
      'exchDisp': 'Taiwan',
      'quoteType': 'EQUITY',
    },
    <String, dynamic>{
      'symbol': 'NVDA25C300',
      'quoteType': 'OPTION', // 選擇權應被過濾
      'exchDisp': 'OPR',
    },
    <String, dynamic>{
      'symbol': 'VOO',
      'shortname': 'Vanguard S&P 500 ETF',
      'exchDisp': 'NYSEArca',
      'quoteType': 'ETF',
    },
  ],
};

void main() {
  group('ParseSearchResponseJson', () {
    test('保留股票與 ETF、過濾選擇權、longname 優先', () {
      final List<SymbolSearchResult> results =
          StockSymbolSearchService.ParseSearchResponseJson(
            SEARCH_RESPONSE_FIXTURE,
          );
      expect(results.length, 3);
      expect(results[0].symbol, 'NVDA');
      expect(results[0].name, 'NVIDIA Corporation');
      expect(results[1].symbol, '2330.TW'); // 台股代號照樣支援
      expect(results[2].quote_type, 'ETF');
    });

    test('格式不符回傳空清單', () {
      expect(
        StockSymbolSearchService.ParseSearchResponseJson(<String, dynamic>{}),
        isEmpty,
      );
    });
  });

  group('ParseNewsResponseJson', () {
    test('解析新聞：標題、來源、時間；缺連結的跳過', () {
      final Map<String, dynamic> fixture = <String, dynamic>{
        'news': <dynamic>[
          <String, dynamic>{
            'title': 'NVIDIA hits new all-time high',
            'publisher': 'Reuters',
            'link': 'https://example.com/nvda',
            'providerPublishTime': 1783713600,
          },
          <String, dynamic>{
            'title': '缺連結的新聞', // link 缺 → 跳過
            'publisher': 'X',
          },
        ],
      };
      final List<StockNewsItem> items =
          StockSymbolSearchService.ParseNewsResponseJson(fixture);
      expect(items.length, 1);
      expect(items.first.title, contains('NVIDIA'));
      expect(items.first.publisher, 'Reuters');
      expect(items.first.published_at, isNotNull);
    });

    test('無 news 欄位回傳空清單', () {
      expect(
        StockSymbolSearchService.ParseNewsResponseJson(<String, dynamic>{}),
        isEmpty,
      );
    });

    test('指定相關代號時會排除不相干新聞', () {
      final Map<String, dynamic> fixture = <String, dynamic>{
        'news': <dynamic>[
          <String, dynamic>{
            'title': 'Taiwan Semiconductor reports earnings',
            'publisher': 'Reuters',
            'link': 'https://example.com/tsm',
            'relatedTickers': <String>['TSM'],
          },
          <String, dynamic>{
            'title': 'McDonald’s shares fall',
            'publisher': 'Yahoo Finance',
            'link': 'https://example.com/mcd',
            'relatedTickers': <String>['MCD'],
          },
        ],
      };
      final List<StockNewsItem> items =
          StockSymbolSearchService.ParseNewsResponseJson(
            fixture,
            relevant_symbols: <String>{'2330.TW', 'TSM'},
          );
      expect(items.length, 1);
      expect(items.single.title, contains('Taiwan Semiconductor'));
    });
  });

  group('SearchSymbols', () {
    test('正常搜尋回傳解析結果', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        expect(request.url.path, '/v1/finance/search');
        expect(request.url.queryParameters['q'], 'NVDA');
        return http.Response(jsonEncode(SEARCH_RESPONSE_FIXTURE), 200);
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      final List<SymbolSearchResult> results = await service.SearchSymbols(
        'NVDA',
      );
      expect(results.length, 3);
    });

    test('429 換備援主機後成功', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        if (request.url.host == 'query1.finance.yahoo.com') {
          return http.Response('Too Many Requests', 429);
        }
        return http.Response(jsonEncode(SEARCH_RESPONSE_FIXTURE), 200);
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      final List<SymbolSearchResult> results = await service.SearchSymbols(
        'NVDA',
      );
      expect(results, isNotEmpty);
    });

    test('全部失敗回傳空清單不拋例外', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        return http.Response('Too Many Requests', 429);
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      expect(await service.SearchSymbols('NVDA'), isEmpty);
    });

    test('空字串不發請求', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        fail('不應發出請求');
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      expect(await service.SearchSymbols('  '), isEmpty);
    });
  });

  group('FetchNewsForSymbol', () {
    test('台股改用公司名稱查詢並只保留相關標的新聞', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        expect(
          request.url.queryParameters['q'],
          'Taiwan Semiconductor Manufacturing Company Limited',
        );
        expect(request.url.queryParameters['quotesCount'], '1');
        expect(request.url.queryParameters['newsCount'], '20');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'quotes': <dynamic>[
              <String, dynamic>{'symbol': 'TSM'},
            ],
            'news': <dynamic>[
              <String, dynamic>{
                'title': 'TSMC raises its outlook',
                'publisher': 'Reuters',
                'link': 'https://example.com/tsm',
                'relatedTickers': <String>['TSM'],
              },
              <String, dynamic>{
                'title': 'Unrelated restaurant news',
                'publisher': 'X',
                'link': 'https://example.com/food',
                'relatedTickers': <String>['MCD'],
              },
            ],
          }),
          200,
        );
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      final List<StockNewsItem> items = await service.FetchNewsForSymbol(
        '2330.TW',
        display_name: 'Taiwan Semiconductor Manufacturing Company Limited',
      );
      expect(items.length, 1);
      expect(items.single.title, 'TSMC raises its outlook');
    });

    test('美股維持以股票代號查詢', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        expect(request.url.queryParameters['q'], 'NVDA');
        expect(request.url.queryParameters['quotesCount'], '0');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'news': <dynamic>[
              <String, dynamic>{
                'title': 'NVIDIA news',
                'publisher': 'Reuters',
                'link': 'https://example.com/nvda',
              },
            ],
          }),
          200,
        );
      });
      final StockSymbolSearchService service = StockSymbolSearchService(
        http_client: mock_client,
      );
      final List<StockNewsItem> items = await service.FetchNewsForSymbol(
        'NVDA',
      );
      expect(items.single.title, 'NVIDIA news');
    });
  });
}

// YahooQuoteService 單元測試：JSON 解析（fixture）、v7 失敗自動走 chart 備援、
// 全部失敗時退避且不拋例外。全程使用 MockClient，不打真網路。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_portfolio_app/models/stock_quote.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';
import 'package:stock_portfolio_app/services/yahoo_quote_service.dart';

/// v7/finance/quote 的單檔結果 fixture（截取自真實回應的欄位子集）。
const Map<String, dynamic> V7_NVDA_FIXTURE = <String, dynamic>{
  'symbol': 'NVDA',
  'marketState': 'POST',
  'regularMarketPrice': 210.96,
  'regularMarketTime': 1783713600, // 2026/07/10 16:00 EDT
  'regularMarketPreviousClose': 202.78,
  'preMarketPrice': 203.5,
  'preMarketTime': 1783678500,
  'postMarketPrice': 211.42,
  'postMarketTime': 1783719000, // 2026/07/10 17:30 EDT
};

/// v8/finance/chart 回應 fixture：最後一筆有效 tick 落在盤後。
const Map<String, dynamic> CHART_NVDA_FIXTURE = <String, dynamic>{
  'chart': <String, dynamic>{
    'result': <dynamic>[
      <String, dynamic>{
        'meta': <String, dynamic>{
          'symbol': 'NVDA',
          'regularMarketPrice': 210.96,
          'regularMarketTime': 1783713600,
          'chartPreviousClose': 202.78,
        },
        'timestamp': <int>[1783713540, 1783719000],
        'indicators': <String, dynamic>{
          'quote': <dynamic>[
            <String, dynamic>{
              'close': <dynamic>[210.9, 211.42],
            },
          ],
        },
      },
    ],
    'error': null,
  },
};

void main() {
  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  group('ParseV7QuoteJson', () {
    test('完整欄位解析：盤前/盤中/盤後價與時間', () {
      final DateTime fetched_at = DateTime(2026, 7, 11);
      final StockQuote quote =
          YahooQuoteService.ParseV7QuoteJson(V7_NVDA_FIXTURE, fetched_at);
      expect(quote.symbol, 'NVDA');
      expect(quote.regular_price, closeTo(210.96, 1e-9));
      expect(quote.regular_time, 1783713600);
      expect(quote.pre_price, closeTo(203.5, 1e-9));
      expect(quote.post_price, closeTo(211.42, 1e-9));
      expect(quote.post_time, 1783719000);
      expect(quote.previous_close, closeTo(202.78, 1e-9));
      expect(quote.market_state, 'POST');
      expect(quote.fetched_at, fetched_at);
    });

    test('缺少盤前/盤後欄位時為 null 不噴例外', () {
      final StockQuote quote = YahooQuoteService.ParseV7QuoteJson(
        <String, dynamic>{'symbol': 'VOO', 'regularMarketPrice': 585},
        DateTime(2026, 7, 11),
      );
      expect(quote.regular_price, closeTo(585.0, 1e-9)); // 整數也轉 double
      expect(quote.pre_price, isNull);
      expect(quote.post_price, isNull);
    });
  });

  group('ParseChartQuoteJson', () {
    test('meta 提供盤中價，最後一筆盤後 tick 推出盤後價', () {
      final StockQuote? quote = YahooQuoteService.ParseChartQuoteJson(
        CHART_NVDA_FIXTURE,
        DateTime(2026, 7, 11),
        MarketSessionResolver(),
      );
      expect(quote, isNotNull);
      expect(quote!.symbol, 'NVDA');
      expect(quote.regular_price, closeTo(210.96, 1e-9));
      // 1783719000 = 2026/07/10 17:30 EDT → 盤後
      expect(quote.post_price, closeTo(211.42, 1e-9));
      expect(quote.post_time, 1783719000);
      expect(quote.previous_close, closeTo(202.78, 1e-9));
    });

    test('格式不符回傳 null', () {
      expect(
          YahooQuoteService.ParseChartQuoteJson(<String, dynamic>{},
              DateTime(2026, 7, 11), MarketSessionResolver()),
          isNull);
    });
  });

  group('FetchRealtimeQuotes - 備援與退避', () {
    test('v7 被限流時自動走 chart 備援取得報價', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        final String path = request.url.path;
        if (request.url.host == 'fc.yahoo.com') {
          return http.Response('', 404, headers: <String, String>{
            'set-cookie': 'A3=d=abc123; Expires=Mon, 15 Mar 2027 12:00:00 GMT; '
                'Path=/; Domain=.yahoo.com',
          });
        }
        if (path.contains('getcrumb')) {
          return http.Response('Too Many Requests', 429);
        }
        if (path.contains('/v7/finance/quote')) {
          return http.Response('Too Many Requests', 429);
        }
        if (path.contains('/v8/finance/chart/NVDA')) {
          return http.Response(jsonEncode(CHART_NVDA_FIXTURE), 200);
        }
        return http.Response('not found', 404);
      });

      final YahooQuoteService service =
          YahooQuoteService(http_client: mock_client);
      final Map<String, StockQuote> quotes =
          await service.FetchRealtimeQuotes(<String>['NVDA']);

      expect(quotes.length, 1);
      expect(quotes['NVDA']!.regular_price, closeTo(210.96, 1e-9));
      expect(service.is_backing_off, isFalse);
    });

    test('主備全部失敗：回傳空 map、進入退避、不拋例外', () async {
      int request_count = 0;
      final MockClient mock_client = MockClient((http.Request request) async {
        request_count++;
        return http.Response('Too Many Requests', 429);
      });

      final YahooQuoteService service =
          YahooQuoteService(http_client: mock_client);
      final Map<String, StockQuote> quotes =
          await service.FetchRealtimeQuotes(<String>['NVDA', 'VOO']);

      expect(quotes, isEmpty);
      expect(service.is_backing_off, isTrue);

      // 退避期間再呼叫：不再發出任何請求
      final int count_before = request_count;
      final Map<String, StockQuote> quotes_during_backoff =
          await service.FetchRealtimeQuotes(<String>['NVDA']);
      expect(quotes_during_backoff, isEmpty);
      expect(request_count, count_before);
    });

    test('v7 成功時批量解析多檔', () async {
      final MockClient mock_client = MockClient((http.Request request) async {
        if (request.url.host == 'fc.yahoo.com') {
          return http.Response('', 404, headers: <String, String>{
            'set-cookie': 'A3=d=abc123; Path=/',
          });
        }
        if (request.url.path.contains('getcrumb')) {
          return http.Response('AbCdEf.123', 200);
        }
        if (request.url.path.contains('/v7/finance/quote')) {
          expect(request.url.queryParameters['crumb'], 'AbCdEf.123');
          expect(request.headers['Cookie'], contains('A3=d=abc123'));
          return http.Response(
              jsonEncode(<String, dynamic>{
                'quoteResponse': <String, dynamic>{
                  'result': <dynamic>[
                    V7_NVDA_FIXTURE,
                    <String, dynamic>{
                      'symbol': 'VOO',
                      'regularMarketPrice': 585.32,
                    },
                  ],
                },
              }),
              200);
        }
        return http.Response('not found', 404);
      });

      final YahooQuoteService service =
          YahooQuoteService(http_client: mock_client);
      final Map<String, StockQuote> quotes =
          await service.FetchRealtimeQuotes(<String>['NVDA', 'VOO']);

      expect(quotes.length, 2);
      expect(quotes['VOO']!.regular_price, closeTo(585.32, 1e-9));
    });
  });

  group('ExtractCookiePairs', () {
    test('expires 內含逗號的多 cookie 合併字串正確切割', () {
      const String set_cookie =
          'A3=d=abc; Expires=Mon, 15 Mar 2027 12:00:00 GMT; Path=/, '
          'B1=xyz789; Path=/; Secure';
      expect(YahooQuoteService.ExtractCookiePairs(set_cookie),
          'A3=d=abc; B1=xyz789');
    });
    test('單一 cookie', () {
      expect(YahooQuoteService.ExtractCookiePairs('A3=d=abc; Path=/'),
          'A3=d=abc');
    });
  });
}

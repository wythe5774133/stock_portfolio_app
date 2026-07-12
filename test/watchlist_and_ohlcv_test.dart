// 追蹤清單 DAO 與 K 線資料解析的單元測試。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

import 'test_database.dart';
import 'package:stock_portfolio_app/models/ohlcv_candle.dart';
import 'package:stock_portfolio_app/services/historical_price_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';

void main() {
  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  group('WatchlistDao', () {
    late AppDatabase database;

    setUp(() {
      database = CreateTestDatabase();
    });

    tearDown(() async {
      await database.close();
    });

    test('加入、重複加入、移除', () async {
      expect(await database.watchlistDao.AddSymbol('TSLA', 'Tesla, Inc.', 1),
          isTrue);
      expect(await database.watchlistDao.AddSymbol('TSLA', 'Tesla, Inc.', 2),
          isFalse); // 重複加入忽略

      final List<WatchlistSymbol> list =
          await database.watchlistDao.GetAllSymbols();
      expect(list.length, 1);
      expect(list.first.symbol, 'TSLA');
      expect(list.first.name, 'Tesla, Inc.');

      await database.watchlistDao.RemoveSymbol('TSLA');
      expect(await database.watchlistDao.GetAllSymbols(), isEmpty);
    });

    test('依加入時間排序', () async {
      await database.watchlistDao.AddSymbol('B', 'B Co', 200);
      await database.watchlistDao.AddSymbol('A', 'A Co', 100);
      final List<WatchlistSymbol> list =
          await database.watchlistDao.GetAllSymbols();
      expect(list.map((WatchlistSymbol w) => w.symbol).toList(),
          <String>['A', 'B']);
    });
  });

  group('ParseOhlcvChartJson', () {
    test('解析開高低收與成交量，缺值 K 線跳過', () {
      final Map<String, dynamic> fixture = <String, dynamic>{
        'chart': <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{
              // 2026/07/08、07/09、07/10 各日 09:30 EDT
              'timestamp': <int>[1783517400, 1783603800, 1783690200],
              'indicators': <String, dynamic>{
                'quote': <dynamic>[
                  <String, dynamic>{
                    'open': <dynamic>[100.0, null, 104.0],
                    'high': <dynamic>[103.0, 105.0, 108.0],
                    'low': <dynamic>[99.0, 101.0, 103.5],
                    'close': <dynamic>[102.0, 104.0, 107.0],
                    'volume': <dynamic>[1000000, 1200000, 900000],
                  },
                ],
              },
            },
          ],
        },
      };
      final List<OhlcvCandle> candles =
          HistoricalPriceService.ParseOhlcvChartJson(fixture);
      expect(candles.length, 2); // 中間一根 open 缺值跳過
      expect(candles.first.date, 20260708);
      expect(candles.first.open, closeTo(100.0, 1e-9));
      expect(candles.first.high, closeTo(103.0, 1e-9));
      expect(candles.first.low, closeTo(99.0, 1e-9));
      expect(candles.first.close, closeTo(102.0, 1e-9));
      expect(candles.first.volume, closeTo(1000000, 1e-9));
      expect(candles.first.is_bullish, isTrue);
      expect(candles.last.date, 20260710);
    });

    test('格式不符回傳空清單不噴例外', () {
      expect(HistoricalPriceService.ParseOhlcvChartJson(<String, dynamic>{}),
          isEmpty);
    });
  });
}

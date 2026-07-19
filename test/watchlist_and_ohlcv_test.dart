// 追蹤清單 DAO 與 K 線資料解析的單元測試。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

import 'test_database.dart';
import 'package:stock_portfolio_app/logic/portfolio_repository.dart';
import 'package:stock_portfolio_app/models/ohlcv_candle.dart';
import 'package:stock_portfolio_app/services/historical_price_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';
import 'package:stock_portfolio_app/ui/dashboard_controller.dart';

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

  group('GetSparklineCloses', () {
    late AppDatabase database;
    late PortfolioRepository repository;
    late DashboardController controller;

    setUp(() {
      database = CreateTestDatabase();
      repository = PortfolioRepository(database: database);
      controller = DashboardController(repository: repository);
    });

    tearDown(() async {
      repository.quote_scheduler.Stop();
      controller.dispose();
      await database.close();
    });

    test('從快取取近 30 筆收盤（由舊到新），超量截尾', () async {
      // 塞 40 個交易日：日期 20260101..20260209（用連號簡化，收盤值等於序號）
      final Map<int, double> closes = <int, double>{
        for (int i = 0; i < 40; i++) 20260101 + i: (i + 1).toDouble(),
      };
      await database.historicalPriceDao.SaveHistoricalCloses('NVDA', closes);

      await controller.LoadSparklineCloses();
      final List<double> series = controller.GetSparklineCloses('NVDA');

      // 只保留最近 30 筆（第 11..40，值為 11..40），且由舊到新
      expect(series.length, 30);
      expect(series.first, 11.0);
      expect(series.last, 40.0);
    });

    test('筆數不足 30 時全數回傳；無快取回空清單', () async {
      await database.historicalPriceDao.SaveHistoricalCloses('AAPL',
          <int, double>{20260101: 100.0, 20260102: 101.0, 20260103: 99.5});

      await controller.LoadSparklineCloses();

      expect(controller.GetSparklineCloses('AAPL'),
          <double>[100.0, 101.0, 99.5]);
      expect(controller.GetSparklineCloses('MSFT'), isEmpty);
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

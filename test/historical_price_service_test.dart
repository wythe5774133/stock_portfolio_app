// HistoricalPriceService 單元測試：日線 JSON 解析與增量快取邏輯。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/services/historical_price_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';

/// 日線 chart 回應 fixture：三個交易日，中間一天收盤為 null（模擬缺值）。
/// 時間戳為美東當日 09:30（Yahoo 日線慣例）。
const Map<String, dynamic> DAILY_CHART_FIXTURE = <String, dynamic>{
  'chart': <String, dynamic>{
    'result': <dynamic>[
      <String, dynamic>{
        'meta': <String, dynamic>{'symbol': 'NVDA'},
        // 2026/07/08、07/09、07/10 各日 09:30 EDT = 13:30 UTC
        'timestamp': <int>[1783518600, 1783605000, 1783691400],
        'indicators': <String, dynamic>{
          'quote': <dynamic>[
            <String, dynamic>{
              'close': <dynamic>[199.5, null, 210.96],
            },
          ],
        },
      },
    ],
  },
};

void main() {
  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  group('ParseChartHistoryJson', () {
    test('時間戳以美東時區換算日期，null 收盤跳過', () {
      final Map<int, double> closes =
          HistoricalPriceService.ParseChartHistoryJson(DAILY_CHART_FIXTURE);
      expect(closes.length, 2);
      expect(closes[20260708], closeTo(199.5, 1e-9));
      expect(closes[20260710], closeTo(210.96, 1e-9));
      expect(closes.containsKey(20260709), isFalse); // null 收盤
    });

    test('格式不符回傳空 map 不噴例外', () {
      expect(HistoricalPriceService.ParseChartHistoryJson(<String, dynamic>{}),
          isEmpty);
    });
  });

  group('SyncHistoricalCloses - 增量快取', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.Memory();
    });

    tearDown(() async {
      await database.close();
    });

    test('首次同步寫入快取；快取已最新時不再發請求', () async {
      int request_count = 0;
      final MockClient mock_client = MockClient((http.Request request) async {
        request_count++;
        return http.Response(jsonEncode(DAILY_CHART_FIXTURE), 200);
      });
      final HistoricalPriceService service = HistoricalPriceService(
        historical_price_dao: database.historicalPriceDao,
        http_client: mock_client,
      );

      await service.SyncHistoricalCloses('NVDA', 20260708);
      expect(request_count, 1);
      final Map<int, double> cached =
          await database.historicalPriceDao.GetHistoricalCloses('NVDA');
      expect(cached.length, 2);

      // 手動把快取補到今天，再同步應不發任何請求
      final DateTime now = DateTime.now();
      final int today = now.year * 10000 + now.month * 100 + now.day;
      await database.historicalPriceDao
          .SaveHistoricalCloses('NVDA', <int, double>{today: 212.0});
      await service.SyncHistoricalCloses('NVDA', 20260708);
      expect(request_count, 1); // 沒有增加
    });

    test('請求失敗（429）時靜默略過，既有快取不受影響', () async {
      await database.historicalPriceDao
          .SaveHistoricalCloses('NVDA', <int, double>{20260708: 199.5});

      final MockClient mock_client = MockClient((http.Request request) async {
        return http.Response('Too Many Requests', 429);
      });
      final HistoricalPriceService service = HistoricalPriceService(
        historical_price_dao: database.historicalPriceDao,
        http_client: mock_client,
      );

      await service.SyncHistoricalCloses('NVDA', 20260708); // 不應拋例外
      final Map<int, double> cached =
          await database.historicalPriceDao.GetHistoricalCloses('NVDA');
      expect(cached[20260708], closeTo(199.5, 1e-9));
    });
  });
}

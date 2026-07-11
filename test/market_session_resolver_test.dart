// MarketSessionResolver 單元測試：夏令/冬令時間與四個時段的邊界。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/models/market_session.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';

void main() {
  final MarketSessionResolver resolver = MarketSessionResolver();

  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  group('夏令時間（EDT，UTC-4）- 2026/07/10 週五', () {
    test('09:30 ET 開盤瞬間為盤中', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 13, 30)),
          MarketSession.regular);
    });
    test('09:29 ET 仍為盤前', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 13, 29)),
          MarketSession.premarket);
    });
    test('04:00 ET 盤前開始', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 8, 0)),
          MarketSession.premarket);
    });
    test('03:59 ET 為休市', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 7, 59)),
          MarketSession.closed);
    });
    test('15:59 ET 仍為盤中', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 19, 59)),
          MarketSession.regular);
    });
    test('16:00 ET 收盤瞬間轉盤後', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 20, 0)),
          MarketSession.postmarket);
    });
    test('19:59 ET 仍為盤後', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 10, 23, 59)),
          MarketSession.postmarket);
    });
    test('20:00 ET 起為休市', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 11, 0, 0)),
          MarketSession.closed);
    });
  });

  group('冬令時間（EST，UTC-5）- 2026/01/05 週一', () {
    test('09:30 ET（14:30 UTC）為盤中', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 1, 5, 14, 30)),
          MarketSession.regular);
    });
    test('09:29 ET（14:29 UTC）為盤前', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 1, 5, 14, 29)),
          MarketSession.premarket);
    });
    test('16:00 ET（21:00 UTC）為盤後', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 1, 5, 21, 0)),
          MarketSession.postmarket);
    });
  });

  group('週末', () {
    test('週六（美東）為休市，即使時間落在平日的盤中區間', () {
      // 2026/07/11 是週六；15:00 UTC = 11:00 EDT
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 11, 15, 0)),
          MarketSession.closed);
    });
    test('週日（美東）為休市', () {
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 12, 15, 0)),
          MarketSession.closed);
    });
    test('UTC 已是週六但美東仍是週五晚間：依美東判斷（盤後結束後為休市）', () {
      // 2026/07/11 01:00 UTC = 2026/07/10 21:00 EDT 週五 → closed（過 20:00）
      expect(resolver.ResolveMarketSessionAt(DateTime.utc(2026, 7, 11, 1, 0)),
          MarketSession.closed);
    });
  });
}

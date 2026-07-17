// 多幣別支援的單元測試：市場判斷、幣別換算、混幣別資產曲線、
// 台股時段判斷，以及全美股組合的迴歸保護。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/logic/market_registry.dart';
import 'package:stock_portfolio_app/logic/portfolio_calculator.dart';
import 'package:stock_portfolio_app/models/market_session.dart';
import 'package:stock_portfolio_app/models/portfolio_snapshot.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';

/// 建立測試用交易的簡便函式。
StockTransaction MakeTx(
  String symbol,
  int date,
  double price,
  double qty,
  TransactionType type,
) {
  return StockTransaction(
    symbol: symbol,
    trade_date: date,
    purchase_price: price,
    quantity: qty,
    transaction_type: type,
  );
}

void main() {
  final PortfolioCalculator calculator = PortfolioCalculator();

  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  group('ResolveMarketForSymbol - 市場與幣別判斷', () {
    test('.TW 後綴為台股／台幣', () {
      final MarketInfo info = ResolveMarketForSymbol('2330.TW');
      expect(info.market_id, 'tw');
      expect(info.currency, 'TWD');
      expect(info.market_label, '台股');
      expect(info.currency_symbol, 'NT\$');
    });

    test('00878.TW（0 開頭）為台股', () {
      expect(ResolveMarketForSymbol('00878.TW').currency, 'TWD');
    });

    test('.TWO 上櫃後綴為台股', () {
      expect(ResolveMarketForSymbol('6488.TWO').market_id, 'tw');
    });

    test('大小寫不敏感：2330.tw 亦為台股', () {
      expect(ResolveMarketForSymbol('2330.tw').currency, 'TWD');
    });

    test('美股個股為美股／美金', () {
      final MarketInfo info = ResolveMarketForSymbol('NVDA');
      expect(info.market_id, 'us');
      expect(info.currency, 'USD');
      expect(info.currency_symbol, '\$');
    });

    test('^ 開頭指數視為美股', () {
      expect(ResolveMarketForSymbol('^GSPC').market_id, 'us');
    });

    test('匯率代號 TWD=X 視為美股（fx，幣別歸類 USD）', () {
      expect(ResolveMarketForSymbol('TWD=X').market_id, 'us');
      expect(ResolveMarketForSymbol(USD_TWD_FX_SYMBOL).currency, 'USD');
    });
  });

  group('ConvertCurrencyValue - 四象限換算', () {
    test('USD → TWD 乘以匯率', () {
      expect(
        PortfolioCalculator.ConvertCurrencyValue(100, 'USD', 'TWD', 32.3),
        closeTo(3230, 1e-9),
      );
    });

    test('TWD → USD 除以匯率', () {
      expect(
        PortfolioCalculator.ConvertCurrencyValue(3230, 'TWD', 'USD', 32.3),
        closeTo(100, 1e-9),
      );
    });

    test('同幣別原值返回（不經乘除）', () {
      expect(
        PortfolioCalculator.ConvertCurrencyValue(123.45, 'USD', 'USD', 32.3),
        123.45,
      );
      expect(
        PortfolioCalculator.ConvertCurrencyValue(678.9, 'TWD', 'TWD', 32.3),
        678.9,
      );
    });

    test('匯率精度：往返換算誤差極小', () {
      const double rate = 31.657;
      final double twd = PortfolioCalculator.ConvertCurrencyValue(
        250.75,
        'USD',
        'TWD',
        rate,
      );
      final double back = PortfolioCalculator.ConvertCurrencyValue(
        twd,
        'TWD',
        'USD',
        rate,
      );
      expect(back, closeTo(250.75, 1e-9));
    });

    test('匯率無效（≤0）不換算，退回原值', () {
      expect(
        PortfolioCalculator.ConvertCurrencyValue(100, 'USD', 'TWD', 0),
        100,
      );
    });
  });

  group('ResolveForwardFilledRate - 匯率往前遞補', () {
    final Map<int, double> rates = <int, double>{
      20260105: 32.0,
      20260108: 32.5,
    };
    final List<int> sorted = rates.keys.toList()..sort();

    test('命中當日直接取用', () {
      expect(
        PortfolioCalculator.ResolveForwardFilledRate(sorted, rates, 20260108),
        32.5,
      );
    });

    test('缺日取 ≤ 該日的最近一筆', () {
      expect(
        PortfolioCalculator.ResolveForwardFilledRate(sorted, rates, 20260107),
        32.0,
      );
    });

    test('早於所有資料取最早一筆', () {
      expect(
        PortfolioCalculator.ResolveForwardFilledRate(sorted, rates, 20260101),
        32.0,
      );
    });

    test('晚於所有資料沿用最後一筆', () {
      expect(
        PortfolioCalculator.ResolveForwardFilledRate(sorted, rates, 20260201),
        32.5,
      );
    });

    test('空匯率表回傳 1.0（等同不換算）', () {
      expect(
        PortfolioCalculator.ResolveForwardFilledRate(
          <int>[],
          <int, double>{},
          20260101,
        ),
        1.0,
      );
    });
  });

  group('CalculateDailyPortfolioHistory - 混幣別逐日市值', () {
    // NVDA(USD) 1 股 + 2330.TW(TWD) 10 股，含匯率缺日測 forward-fill。
    final List<StockTransaction> transactions = <StockTransaction>[
      MakeTx('NVDA', 20260105, 100, 1.0, TransactionType.buy),
      MakeTx('2330.TW', 20260105, 1000, 10.0, TransactionType.buy),
    ];
    final Map<String, Map<int, double>> closes = <String, Map<int, double>>{
      'NVDA': <int, double>{20260105: 100, 20260106: 110},
      '2330.TW': <int, double>{20260105: 1000, 20260106: 1050},
    };
    // 匯率只給 1/5（1 USD = 32 TWD），1/6 缺 → forward-fill 沿用 32
    final Map<int, double> usd_twd = <int, double>{20260105: 32.0};

    test('顯示 USD：台股市值除以匯率後併入', () {
      final List<PortfolioSnapshot> snapshots = calculator
          .CalculateDailyPortfolioHistory(
            transactions,
            closes,
            20260106,
            display_currency: 'USD',
            usd_twd_by_date: usd_twd,
          );
      // 1/5：NVDA 1×100=100 USD；2330 10×1000=10000 TWD ÷32=312.5 → 412.5
      expect(snapshots[0].total_market_value, closeTo(412.5, 1e-6));
      // 1/5 現金流：買入 100 USD + 10000 TWD÷32=312.5 → 412.5
      expect(snapshots[0].net_cash_flow, closeTo(412.5, 1e-6));
      // 1/6（匯率缺，沿用32）：NVDA 110；2330 10×1050=10500÷32=328.125 → 438.125
      expect(snapshots[1].total_market_value, closeTo(438.125, 1e-6));
    });

    test('顯示 TWD：美股市值乘以匯率後併入', () {
      final List<PortfolioSnapshot> snapshots = calculator
          .CalculateDailyPortfolioHistory(
            transactions,
            closes,
            20260106,
            display_currency: 'TWD',
            usd_twd_by_date: usd_twd,
          );
      // 1/5：NVDA 100 USD ×32=3200；2330 10000 TWD → 13200
      expect(snapshots[0].total_market_value, closeTo(13200, 1e-6));
      // 1/6：NVDA 110×32=3520；2330 10500 → 14020
      expect(snapshots[1].total_market_value, closeTo(14020, 1e-6));
    });

    test('forward-fill：匯率變動日之前沿用舊匯率', () {
      // 追加 1/6 匯率 33，驗證 1/6 用新匯率、1/5 用舊匯率
      final Map<int, double> two_rates = <int, double>{
        20260105: 32.0,
        20260106: 33.0,
      };
      final List<PortfolioSnapshot> snapshots = calculator
          .CalculateDailyPortfolioHistory(
            transactions,
            closes,
            20260106,
            display_currency: 'TWD',
            usd_twd_by_date: two_rates,
          );
      expect(snapshots[0].total_market_value, closeTo(13200, 1e-6)); // 32
      // 1/6：NVDA 110×33=3630；2330 10500 → 14130
      expect(snapshots[1].total_market_value, closeTo(14130, 1e-6));
    });
  });

  group('全美股組合迴歸保護 - 新舊簽名結果一致', () {
    final List<StockTransaction> transactions = <StockTransaction>[
      MakeTx('A', 20260105, 10, 2.0, TransactionType.buy),
      MakeTx('B', 20260106, 20, 1.0, TransactionType.buy),
    ];
    final Map<String, Map<int, double>> closes = <String, Map<int, double>>{
      'A': <int, double>{20260105: 11, 20260107: 12},
      'B': <int, double>{20260106: 22},
    };

    test('預設參數（USD、空匯率）與帶入 USD 顯示結果相同', () {
      final List<PortfolioSnapshot> legacy = calculator
          .CalculateDailyPortfolioHistory(transactions, closes, 20260108);
      final List<PortfolioSnapshot> explicit = calculator
          .CalculateDailyPortfolioHistory(
            transactions,
            closes,
            20260108,
            display_currency: 'USD',
            usd_twd_by_date: <int, double>{20260105: 32.0},
          );
      expect(legacy.length, explicit.length);
      for (int i = 0; i < legacy.length; i++) {
        expect(explicit[i].total_market_value, legacy[i].total_market_value);
        expect(explicit[i].total_cost_basis, legacy[i].total_cost_basis);
        expect(explicit[i].net_cash_flow, legacy[i].net_cash_flow);
      }
    });
  });

  group('ResolveSessionForMarket - 台股時段', () {
    final MarketSessionResolver resolver = MarketSessionResolver();

    test('台北週三 10:00 為盤中', () {
      // 2026/07/15 週三 10:00 台北 = 02:00 UTC
      expect(
        resolver.ResolveSessionForMarket('tw', DateTime.utc(2026, 7, 15, 2, 0)),
        MarketSession.regular,
      );
    });

    test('台北週三 14:00 為休市（收盤後）', () {
      // 14:00 台北 = 06:00 UTC
      expect(
        resolver.ResolveSessionForMarket('tw', DateTime.utc(2026, 7, 15, 6, 0)),
        MarketSession.closed,
      );
    });

    test('台北週三 09:00 開盤瞬間為盤中', () {
      // 09:00 台北 = 01:00 UTC
      expect(
        resolver.ResolveSessionForMarket('tw', DateTime.utc(2026, 7, 15, 1, 0)),
        MarketSession.regular,
      );
    });

    test('台北週三 13:30 收盤瞬間為休市', () {
      // 13:30 台北 = 05:30 UTC
      expect(
        resolver.ResolveSessionForMarket(
          'tw',
          DateTime.utc(2026, 7, 15, 5, 30),
        ),
        MarketSession.closed,
      );
    });

    test('台北週六為休市', () {
      // 2026/07/18 週六 10:00 台北 = 02:00 UTC
      expect(
        resolver.ResolveSessionForMarket('tw', DateTime.utc(2026, 7, 18, 2, 0)),
        MarketSession.closed,
      );
    });

    test('台股永不回傳盤前盤後', () {
      // 08:30 台北（盤前時段）應為休市，非 premarket
      final MarketSession early =
          resolver.ResolveSessionForMarket('tw', DateTime.utc(2026, 7, 15, 0, 30));
      expect(early, MarketSession.closed);
      expect(early, isNot(MarketSession.premarket));
    });

    test('美股時段不受影響（us 沿用四段制）', () {
      // 2026/07/10 週五 13:30 UTC = 09:30 EDT 盤中
      expect(
        resolver.ResolveSessionForMarket(
          'us',
          DateTime.utc(2026, 7, 10, 13, 30),
        ),
        MarketSession.regular,
      );
    });
  });

  group('CalculateXirr - 混幣別 smoke test', () {
    test('已換算現金流可求解且落在合理範圍', () {
      // 模擬：台股買入（已換算為 USD 的負現金流）＋期末市值（USD）
      final double? xirr = calculator.CalculateXirr(<(int, double)>[
        (20250101, -1000), // 台股買入換算後
        (20250601, -500), // 美股買入
        (20260101, 1700), // 期末總市值（已換算）
      ]);
      expect(xirr, isNotNull);
      expect(xirr!.isFinite, isTrue);
      expect(xirr, greaterThan(-1));
      expect(xirr, lessThan(10));
    });
  });
}

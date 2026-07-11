// 期間損益與時間加權報酬率的單元測試：
// 驗證新投入本金不會被誤算成獲利，以及大盤報酬率序列對齊。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/logic/portfolio_calculator.dart';
import 'package:stock_portfolio_app/models/portfolio_snapshot.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';

/// 建立測試快照的簡便函式。
PortfolioSnapshot MakeSnapshot(int date, double mv, double cost,
    {double flow = 0}) {
  return PortfolioSnapshot(
    date: date,
    total_market_value: mv,
    total_cost_basis: cost,
    net_cash_flow: flow,
  );
}

void main() {
  final PortfolioCalculator calculator = PortfolioCalculator();

  group('CalculateDailyPortfolioHistory - 現金流記錄', () {
    test('買入日記正的淨投入、賣出日記負的（賣出所得）', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        const StockTransaction(
            symbol: 'A',
            trade_date: 20260101,
            purchase_price: 100,
            quantity: 2,
            transaction_type: TransactionType.buy),
        const StockTransaction(
            symbol: 'A',
            trade_date: 20260103,
            purchase_price: 110,
            quantity: 1,
            transaction_type: TransactionType.sell),
      ];
      final List<PortfolioSnapshot> snapshots =
          calculator.CalculateDailyPortfolioHistory(
              transactions,
              <String, Map<int, double>>{
            'A': <int, double>{20260101: 100, 20260102: 105, 20260103: 110},
          },
              20260103);
      expect(snapshots[0].net_cash_flow, closeTo(200, 1e-9)); // 買入 2×100
      expect(snapshots[1].net_cash_flow, closeTo(0, 1e-9));
      expect(snapshots[2].net_cash_flow, closeTo(-110, 1e-9)); // 賣出 1×110
    });
  });

  group('CalculatePeriodPnl - 期間損益', () {
    test('純市場漲跌（無現金流）', () {
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 1000, 900),
        MakeSnapshot(20260102, 1050, 900),
        MakeSnapshot(20260103, 1100, 900),
      ];
      expect(calculator.CalculatePeriodPnl(range), closeTo(100, 1e-9));
    });

    test('期間有新投入：本金不算獲利', () {
      // 期初 1000 → 加碼 500 → 期末 1560：實際只賺 60
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 1000, 900),
        MakeSnapshot(20260102, 1510, 1400, flow: 500),
        MakeSnapshot(20260103, 1560, 1400),
      ];
      expect(calculator.CalculatePeriodPnl(range), closeTo(60, 1e-9));
    });

    test('期間有賣出提領：提走的錢不算虧損', () {
      // 期初 1000 → 賣出提走 300 → 期末 750：實際賺 50
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 1000, 900),
        MakeSnapshot(20260102, 720, 630, flow: -300),
        MakeSnapshot(20260103, 750, 630),
      ];
      expect(calculator.CalculatePeriodPnl(range), closeTo(50, 1e-9));
    });

    test('快照不足兩筆回傳 0', () {
      expect(calculator.CalculatePeriodPnl(<PortfolioSnapshot>[]), 0);
      expect(
          calculator
              .CalculatePeriodPnl(<PortfolioSnapshot>[MakeSnapshot(1, 1, 1)]),
          0);
    });
  });

  group('CalculateCumulativeReturnPercentSeries - 時間加權報酬率', () {
    test('無現金流：等同單純漲幅', () {
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 1000, 900),
        MakeSnapshot(20260102, 1100, 900),
        MakeSnapshot(20260103, 990, 900),
      ];
      final List<double> series =
          calculator.CalculateCumulativeReturnPercentSeries(range);
      expect(series[0], closeTo(0, 1e-9));
      expect(series[1], closeTo(10, 1e-9)); // +10%
      expect(series[2], closeTo(-1, 1e-9)); // 1000→990 = -1%
    });

    test('加碼日的本金不計入報酬', () {
      // day1: 1000；day2: 加碼 1000 且市場漲 5% → MV = (1000+1000)*1.05 = 2100
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 1000, 1000),
        MakeSnapshot(20260102, 2100, 2000, flow: 1000),
      ];
      final List<double> series =
          calculator.CalculateCumulativeReturnPercentSeries(range);
      expect(series[1], closeTo(5, 1e-9)); // 報酬率 5%，不是 110%
    });

    test('前一日市值為 0（期間內第一筆買入）不會除以零', () {
      final List<PortfolioSnapshot> range = <PortfolioSnapshot>[
        MakeSnapshot(20260101, 0, 0),
        MakeSnapshot(20260102, 1000, 1000, flow: 1000),
        MakeSnapshot(20260103, 1100, 1000),
      ];
      final List<double> series =
          calculator.CalculateCumulativeReturnPercentSeries(range);
      expect(series[1], closeTo(0, 1e-9)); // 買入當天不產生報酬
      expect(series[2], closeTo(10, 1e-9));
    });
  });

  group('BuildBenchmarkReturnPercentSeries - 大盤序列對齊', () {
    test('非交易日沿用前收、起點歸零、無資料日為 null', () {
      final Map<int, double> closes = <int, double>{
        20260102: 100,
        20260105: 110,
      };
      final List<int> dates = <int>[
        20260101, // 指數尚無資料 → null
        20260102, // 基準日 0%
        20260103, // 週末沿用 → 0%
        20260104,
        20260105, // +10%
      ];
      final List<double?> series =
          PortfolioCalculator.BuildBenchmarkReturnPercentSeries(closes, dates);
      expect(series[0], isNull);
      expect(series[1], closeTo(0, 1e-9));
      expect(series[2], closeTo(0, 1e-9));
      expect(series[4], closeTo(10, 1e-9));
    });

    test('完全無資料：全 null', () {
      final List<double?> series =
          PortfolioCalculator.BuildBenchmarkReturnPercentSeries(
              <int, double>{}, <int>[20260101, 20260102]);
      expect(series.every((double? v) => v == null), isTrue);
    });
  });
}

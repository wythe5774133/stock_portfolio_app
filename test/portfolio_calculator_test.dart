// PortfolioCalculator 單元測試：加權平均成本、已實現損益、邊界情境與資產曲線重建。
// NVDA/AAPL 等期望值為依加權平均法手工推導的已知答案。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/logic/portfolio_calculator.dart';
import 'package:stock_portfolio_app/models/holding_position.dart';
import 'package:stock_portfolio_app/models/portfolio_snapshot.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/csv_transaction_importer.dart';

/// 建立測試用交易的簡便函式。
StockTransaction MakeTransaction(String symbol, int date, double price,
    double quantity, TransactionType type) {
  return StockTransaction(
    symbol: symbol,
    trade_date: date,
    purchase_price: price,
    quantity: quantity,
    transaction_type: type,
  );
}

void main() {
  final PortfolioCalculator calculator = PortfolioCalculator();

  group('CalculateHoldingPositions - 範例 CSV 已知答案', () {
    late Map<String, HoldingPosition> by_symbol;

    setUpAll(() {
      final String csv_content =
          File('test/fixtures/sample_transactions.csv').readAsStringSync();
      final CsvParseResult parsed =
          CsvTransactionImporter().ParseCsvTransactions(csv_content);
      final List<HoldingPosition> positions =
          calculator.CalculateHoldingPositions(parsed.transactions);
      by_symbol = <String, HoldingPosition>{
        for (final HoldingPosition p in positions) p.symbol: p,
      };
    });

    test('NVDA：碎股加權平均與賣出沖銷', () {
      // 手工推導：
      // BUY 2.0@152.6 → qty 2.0, cost 305.2
      // BUY 1.5@178.25 → qty 3.5, cost 572.575, avg 163.592857
      // SELL 0.41538@205 → realized (205-163.592857)*0.41538 = 17.1999
      //                    cost 504.621799, qty 3.08462（avg 不變）
      // BUY 0.77129@194.478914 → qty 3.85591, cost 654.621441, avg 169.7709
      final HoldingPosition nvda = by_symbol['NVDA']!;
      expect(nvda.net_quantity, closeTo(3.85591, 1e-6));
      expect(nvda.average_cost, closeTo(169.7709, 0.01));
      expect(nvda.realized_pnl, closeTo(17.20, 0.01));
      expect(nvda.total_cost_basis, closeTo(654.6214, 0.01));
      expect(nvda.is_closed, isFalse);
      expect(nvda.transactions.length, 4);
    });

    test('AAPL：賣在均價之下產生負的已實現損益', () {
      // BUY 3@241.8 + BUY 2@215.4 → qty 5, avg 231.24
      // SELL 1.5@228 → realized (228-231.24)*1.5 = -4.86, qty 3.5
      final HoldingPosition aapl = by_symbol['AAPL']!;
      expect(aapl.net_quantity, closeTo(3.5, 1e-9));
      expect(aapl.average_cost, closeTo(231.24, 0.01));
      expect(aapl.realized_pnl, closeTo(-4.86, 0.01));
    });

    test('VOO：純買入的加權平均', () {
      final HoldingPosition voo = by_symbol['VOO']!;
      expect(voo.net_quantity, closeTo(3.0, 1e-9));
      expect(voo.average_cost, closeTo(558.4833, 0.01));
      expect(voo.realized_pnl, closeTo(0.0, 1e-9));
    });

    test('GOOG：單筆買入', () {
      final HoldingPosition goog = by_symbol['GOOG']!;
      expect(goog.net_quantity, closeTo(2.5, 1e-9));
      expect(goog.average_cost, closeTo(192.3, 0.01));
    });
  });

  group('CalculateHoldingPositions - 邊界情境', () {
    test('賣超過持有量的交易視為錯誤資料跳過', () {
      final List<HoldingPosition> positions =
          calculator.CalculateHoldingPositions(<StockTransaction>[
        MakeTransaction('X', 20260101, 100, 1.0, TransactionType.buy),
        MakeTransaction('X', 20260102, 120, 5.0, TransactionType.sell),
      ]);
      final HoldingPosition x = positions.single;
      expect(x.net_quantity, closeTo(1.0, 1e-9));
      expect(x.realized_pnl, closeTo(0.0, 1e-9));
    });

    test('清倉後再買入：成本從零重新累積', () {
      final List<HoldingPosition> positions =
          calculator.CalculateHoldingPositions(<StockTransaction>[
        MakeTransaction('Y', 20260101, 100, 2.0, TransactionType.buy),
        MakeTransaction('Y', 20260102, 120, 2.0, TransactionType.sell),
        MakeTransaction('Y', 20260103, 50, 1.0, TransactionType.buy),
      ]);
      final HoldingPosition y = positions.single;
      expect(y.realized_pnl, closeTo(40.0, 1e-6)); // (120-100)*2
      expect(y.net_quantity, closeTo(1.0, 1e-9));
      expect(y.average_cost, closeTo(50.0, 1e-6)); // 不受前一輪污染
    });

    test('完全清倉的代號保留且 is_closed 為 true', () {
      final List<HoldingPosition> positions =
          calculator.CalculateHoldingPositions(<StockTransaction>[
        MakeTransaction('Z', 20260101, 100, 2.0, TransactionType.buy),
        MakeTransaction('Z', 20260102, 110, 2.0, TransactionType.sell),
      ]);
      final HoldingPosition z = positions.single;
      expect(z.is_closed, isTrue);
      expect(z.realized_pnl, closeTo(20.0, 1e-6));
      expect(z.total_cost_basis, closeTo(0.0, 1e-9));
    });

    test('交易順序打亂也依日期正確重播', () {
      final List<HoldingPosition> positions =
          calculator.CalculateHoldingPositions(<StockTransaction>[
        MakeTransaction('W', 20260103, 120, 1.0, TransactionType.sell),
        MakeTransaction('W', 20260101, 100, 2.0, TransactionType.buy),
      ]);
      final HoldingPosition w = positions.single;
      expect(w.net_quantity, closeTo(1.0, 1e-9));
      expect(w.realized_pnl, closeTo(20.0, 1e-6));
    });
  });

  group('CalculateDailyPortfolioHistory - 資產曲線重建', () {
    test('逐日市值與成本：含缺價沿用與多檔加總', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        MakeTransaction('A', 20260105, 10, 2.0, TransactionType.buy),
        MakeTransaction('B', 20260106, 20, 1.0, TransactionType.buy),
      ];
      final Map<String, Map<int, double>> closes = <String, Map<int, double>>{
        'A': <int, double>{20260105: 11, 20260107: 12},
        'B': <int, double>{20260106: 22},
      };
      final List<PortfolioSnapshot> snapshots = calculator
          .CalculateDailyPortfolioHistory(transactions, closes, 20260108);

      expect(snapshots.length, 4); // 1/5 ~ 1/8
      // 1/5：A 2股 × 收盤11 = 22，成本 20
      expect(snapshots[0].date, 20260105);
      expect(snapshots[0].total_market_value, closeTo(22, 1e-9));
      expect(snapshots[0].total_cost_basis, closeTo(20, 1e-9));
      // 1/6：A 無收盤沿用11 = 22；B 1股 × 22 = 22 → 44，成本 40
      expect(snapshots[1].total_market_value, closeTo(44, 1e-9));
      expect(snapshots[1].total_cost_basis, closeTo(40, 1e-9));
      // 1/7：A 收盤12 → 24 + B 沿用22 → 46
      expect(snapshots[2].total_market_value, closeTo(46, 1e-9));
      // 1/8：全部沿用 → 46
      expect(snapshots[3].total_market_value, closeTo(46, 1e-9));
    });

    test('完全沒有歷史股價時以買入價代替（曲線第一天就有值）', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        MakeTransaction('C', 20260110, 55, 2.0, TransactionType.buy),
      ];
      final List<PortfolioSnapshot> snapshots =
          calculator.CalculateDailyPortfolioHistory(
              transactions, <String, Map<int, double>>{}, 20260111);
      expect(snapshots.first.total_market_value, closeTo(110, 1e-9));
      expect(snapshots.first.total_cost_basis, closeTo(110, 1e-9));
    });

    test('賣出反映在後續持股與成本', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        MakeTransaction('D', 20260101, 100, 2.0, TransactionType.buy),
        MakeTransaction('D', 20260103, 110, 1.0, TransactionType.sell),
      ];
      final Map<String, Map<int, double>> closes = <String, Map<int, double>>{
        'D': <int, double>{20260101: 100, 20260102: 105, 20260103: 110},
      };
      final List<PortfolioSnapshot> snapshots = calculator
          .CalculateDailyPortfolioHistory(transactions, closes, 20260103);
      // 1/3：剩 1 股 × 110 = 110，成本剩 100
      expect(snapshots[2].total_market_value, closeTo(110, 1e-9));
      expect(snapshots[2].total_cost_basis, closeTo(100, 1e-9));
    });

    test('無交易回傳空清單', () {
      expect(
          calculator.CalculateDailyPortfolioHistory(
              <StockTransaction>[], <String, Map<int, double>>{}, 20260101),
          isEmpty);
    });
  });
}

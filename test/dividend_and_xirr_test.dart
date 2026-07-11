// 股息收入計算、XIRR 求解與配息 JSON 解析的單元測試。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/logic/portfolio_calculator.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/dividend_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';

/// 建立測試交易的簡便函式。
StockTransaction MakeTx(String symbol, int date, double price, double qty,
    TransactionType type) {
  return StockTransaction(
    symbol: symbol,
    trade_date: date,
    purchase_price: price,
    quantity: qty,
    transaction_type: type,
  );
}

void main() {
  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);
  final PortfolioCalculator calculator = PortfolioCalculator();

  group('CalculateDividendIncomeBySymbol', () {
    test('除息日前持有才計息、賣出後不計', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        MakeTx('VOO', 20260101, 500, 2, TransactionType.buy),
        MakeTx('VOO', 20260401, 550, 1, TransactionType.sell),
      ];
      final Map<String, Map<int, double>> events = <String, Map<int, double>>{
        'VOO': <int, double>{
          20260320: 1.5, // 持有 2 股 → 3.0
          20260620: 1.6, // 賣剩 1 股 → 1.6
        },
      };
      final Map<String, double> income =
          calculator.CalculateDividendIncomeBySymbol(transactions, events);
      expect(income['VOO'], closeTo(3.0 + 1.6, 1e-9));
    });

    test('除息日當天才買入的不計息', () {
      final List<StockTransaction> transactions = <StockTransaction>[
        MakeTx('AAPL', 20260320, 230, 5, TransactionType.buy),
      ];
      final Map<String, Map<int, double>> events = <String, Map<int, double>>{
        'AAPL': <int, double>{20260320: 0.25},
      };
      expect(
          calculator.CalculateDividendIncomeBySymbol(transactions, events),
          isEmpty);
    });

    test('沒有交易紀錄的代號忽略其配息事件', () {
      final Map<String, double> income =
          calculator.CalculateDividendIncomeBySymbol(
              <StockTransaction>[],
              <String, Map<int, double>>{
            'MSFT': <int, double>{20260101: 0.75},
          });
      expect(income, isEmpty);
    });
  });

  group('CalculateXirr', () {
    test('一年整報酬 10% 的單筆投資：XIRR ≈ 10%', () {
      final double? xirr = calculator.CalculateXirr(<(int, double)>[
        (20250101, -1000),
        (20260101, 1100),
      ]);
      expect(xirr, isNotNull);
      expect(xirr!, closeTo(0.10, 0.001));
    });

    test('半年賺 5%：年化約 10.25%（複利）', () {
      // 182.5 天 ≈ 0.5 年：(1.05)^2 - 1 ≈ 10.25%
      final double? xirr = calculator.CalculateXirr(<(int, double)>[
        (20250101, -1000),
        (20250702, 1050), // 182 天後
      ]);
      expect(xirr, isNotNull);
      expect(xirr!, closeTo(0.1029, 0.005));
    });

    test('多筆現金流（分批買入＋股息＋期末市值）可求解', () {
      final double? xirr = calculator.CalculateXirr(<(int, double)>[
        (20250101, -1000),
        (20250601, -500),
        (20250915, 20), // 股息
        (20260101, 1650),
      ]);
      expect(xirr, isNotNull);
      expect(xirr!, greaterThan(0)); // 賺錢
      expect(xirr, lessThan(0.25));
    });

    test('虧損情境：XIRR 為負', () {
      final double? xirr = calculator.CalculateXirr(<(int, double)>[
        (20250101, -1000),
        (20260101, 800),
      ]);
      expect(xirr, isNotNull);
      expect(xirr!, closeTo(-0.20, 0.001));
    });

    test('無法求解的情境回傳 null', () {
      // 全部同號
      expect(
          calculator.CalculateXirr(<(int, double)>[
            (20250101, -1000),
            (20250601, -500),
          ]),
          isNull);
      // 少於兩筆
      expect(calculator.CalculateXirr(<(int, double)>[(20250101, -1)]),
          isNull);
      // 全部同一天（無時間跨度，兩端同號）
      expect(
          calculator.CalculateXirr(<(int, double)>[
            (20250101, -1000),
            (20250101, 1100),
          ]),
          isNull);
    });
  });

  group('ParseDividendEventsJson', () {
    test('解析 events.dividends 並以美東時區換算除息日', () {
      final Map<String, dynamic> fixture = <String, dynamic>{
        'chart': <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{
              'events': <String, dynamic>{
                'dividends': <String, dynamic>{
                  // 2026/03/20 09:30 EDT = 13:30 UTC
                  '1773840600': <String, dynamic>{
                    'amount': 1.7237,
                    'date': 1773840600,
                  },
                },
              },
            },
          ],
        },
      };
      final Map<int, double> events =
          DividendService.ParseDividendEventsJson(fixture);
      expect(events.length, 1);
      expect(events.values.first, closeTo(1.7237, 1e-9));
    });

    test('無配息（沒有 events 區塊）回傳空 map', () {
      expect(
          DividendService.ParseDividendEventsJson(<String, dynamic>{
            'chart': <String, dynamic>{
              'result': <dynamic>[<String, dynamic>{}],
            },
          }),
          isEmpty);
    });
  });
}

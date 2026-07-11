// 投資組合計算引擎：加權平均成本法的持倉彙總，與逐日重播的資產曲線重建。
// 純 Dart 邏輯，不依賴資料庫與網路，方便單元測試。

import '../models/holding_position.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_transaction.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   PortfolioCalculator
 *
 * @brief   由逐筆交易紀錄計算持倉、損益與歷史資產曲線。
 *
 * @note    成本沖銷採「加權平均法」：賣出時以當下平均成本認列已實現損益，
 *          平均成本不變；全部賣光後成本歸零重新累積。
 *          賣出量超過持有量的交易視為資料錯誤，跳過不計。
 */
class PortfolioCalculator {
  /// App 內顯示用的成本計算方法名稱。
  static const String COST_METHOD_NAME = '加權平均法';

  /// 浮點數量比較容差（碎股計算用）
  static const double QUANTITY_EPSILON = 1e-9;

  /*
   *  @fn      List<HoldingPosition> CalculateHoldingPositions(List<StockTransaction> transactions)
   *
   *  @brief   ( 依代號分組重播交易，計算每檔的淨持股、平均成本與已實現損益 )
   *
   *  @param   transactions - 全部交易紀錄（順序不拘，內部會依日期排序）
   *
   *  @return  持倉清單，依代號字母排序；已清倉者仍保留（is_closed = true）
   *
   *  @note    賣出量若超過目前持有量（含容差），該筆跳過不影響其餘計算。
   */
  List<HoldingPosition> CalculateHoldingPositions(
      List<StockTransaction> transactions) {
    final Map<String, List<StockTransaction>> grouped =
        GroupTransactionsBySymbol(transactions);

    final List<HoldingPosition> positions = <HoldingPosition>[];
    for (final String symbol in grouped.keys.toList()..sort()) {
      final List<StockTransaction> symbol_transactions = grouped[symbol]!;

      double total_quantity = 0.0;
      double total_cost = 0.0;
      double realized_pnl = 0.0;

      for (final StockTransaction tx in symbol_transactions) {
        if (tx.transaction_type == TransactionType.buy) {
          total_cost += tx.purchase_price * tx.quantity;
          total_quantity += tx.quantity;
        } else {
          // 賣出量超過持有量：資料錯誤，跳過
          if (tx.quantity > total_quantity + QUANTITY_EPSILON) {
            continue;
          }
          final double average_cost =
              total_quantity > QUANTITY_EPSILON ? total_cost / total_quantity : 0.0;
          realized_pnl += (tx.purchase_price - average_cost) * tx.quantity;
          total_cost -= average_cost * tx.quantity;
          total_quantity -= tx.quantity;
          // 清倉時把浮點殘值歸零，避免下一輪買入被污染
          if (total_quantity < QUANTITY_EPSILON) {
            total_quantity = 0.0;
            total_cost = 0.0;
          }
        }
      }

      final double average_cost =
          total_quantity > QUANTITY_EPSILON ? total_cost / total_quantity : 0.0;
      positions.add(HoldingPosition(
        symbol: symbol,
        net_quantity: total_quantity,
        average_cost: average_cost,
        total_cost_basis: total_cost,
        realized_pnl: realized_pnl,
        transactions: symbol_transactions,
      ));
    }
    return positions;
  }

  /*
   *  @fn      List<PortfolioSnapshot> CalculateDailyPortfolioHistory(
   *               List<StockTransaction> transactions,
   *               Map<String, Map<int, double>> historical_closes,
   *               int today_date)
   *
   *  @brief   ( 從最早交易日逐日重播，重建每一天的組合總市值與累計成本 )
   *
   *  @param   transactions - 全部交易紀錄
   *  @param   historical_closes - {symbol: {yyyyMMdd: 收盤價}} 歷史日線
   *  @param   today_date - 曲線終點日期（yyyyMMdd），通常為今天
   *
   *  @return  由舊到新的每日快照清單；無交易時回傳空清單
   *
   *  @note    無收盤價的日期（週末、假日）沿用前一個已知價格；
   *           某代號尚無任何歷史價時，以最近一次買入價代替，
   *           確保曲線從第一天起就有合理數值。
   */
  List<PortfolioSnapshot> CalculateDailyPortfolioHistory(
    List<StockTransaction> transactions,
    Map<String, Map<int, double>> historical_closes,
    int today_date,
  ) {
    if (transactions.isEmpty) {
      return <PortfolioSnapshot>[];
    }

    final Map<String, List<StockTransaction>> grouped =
        GroupTransactionsBySymbol(transactions);

    // 各代號的重播狀態
    final Map<String, double> quantity_by_symbol = <String, double>{};
    final Map<String, double> cost_by_symbol = <String, double>{};
    final Map<String, double> last_known_price = <String, double>{};
    final Map<String, int> next_tx_index = <String, int>{
      for (final String s in grouped.keys) s: 0,
    };

    final int earliest_date = transactions
        .map((StockTransaction t) => t.trade_date)
        .reduce((int a, int b) => a < b ? a : b);

    DateTime cursor = ConvertYyyymmddToDateTime(earliest_date);
    final DateTime end = ConvertYyyymmddToDateTime(today_date);

    final List<PortfolioSnapshot> snapshots = <PortfolioSnapshot>[];
    while (!cursor.isAfter(end)) {
      final int date = ConvertDateTimeToYyyymmdd(cursor);

      // 先套用當日全部交易，同時累計當日淨投入現金流
      double day_cash_flow = 0.0;
      for (final String symbol in grouped.keys) {
        final List<StockTransaction> txs = grouped[symbol]!;
        int index = next_tx_index[symbol]!;
        while (index < txs.length && txs[index].trade_date <= date) {
          final StockTransaction tx = txs[index];
          final double quantity = quantity_by_symbol[symbol] ?? 0.0;
          final double cost = cost_by_symbol[symbol] ?? 0.0;
          if (tx.transaction_type == TransactionType.buy) {
            quantity_by_symbol[symbol] = quantity + tx.quantity;
            cost_by_symbol[symbol] = cost + tx.purchase_price * tx.quantity;
            day_cash_flow += tx.purchase_price * tx.quantity;
            // 尚無歷史價時以買入價當作已知價格起點
            last_known_price.putIfAbsent(symbol, () => tx.purchase_price);
          } else if (tx.quantity <= quantity + QUANTITY_EPSILON) {
            final double average_cost =
                quantity > QUANTITY_EPSILON ? cost / quantity : 0.0;
            double new_quantity = quantity - tx.quantity;
            double new_cost = cost - average_cost * tx.quantity;
            if (new_quantity < QUANTITY_EPSILON) {
              new_quantity = 0.0;
              new_cost = 0.0;
            }
            quantity_by_symbol[symbol] = new_quantity;
            cost_by_symbol[symbol] = new_cost;
            day_cash_flow -= tx.purchase_price * tx.quantity; // 賣出所得
          }
          index++;
        }
        next_tx_index[symbol] = index;
      }

      // 更新當日已知價格並累計市值與成本
      double total_market_value = 0.0;
      double total_cost_basis = 0.0;
      for (final String symbol in grouped.keys) {
        final double quantity = quantity_by_symbol[symbol] ?? 0.0;
        final double? today_close = historical_closes[symbol]?[date];
        if (today_close != null) {
          last_known_price[symbol] = today_close;
        }
        if (quantity > QUANTITY_EPSILON) {
          total_market_value += quantity * (last_known_price[symbol] ?? 0.0);
          total_cost_basis += cost_by_symbol[symbol] ?? 0.0;
        }
      }

      snapshots.add(PortfolioSnapshot(
        date: date,
        total_market_value: total_market_value,
        total_cost_basis: total_cost_basis,
        net_cash_flow: day_cash_flow,
      ));

      cursor = cursor.add(const Duration(days: 1));
    }
    return snapshots;
  }

  /*
   *  @fn      double CalculatePeriodPnl(List<PortfolioSnapshot> range_snapshots)
   *
   *  @brief   ( 計算指定期間的損益：市值變化扣除期間淨投入本金 )
   *
   *  @param   range_snapshots - 期間內的每日快照（第一筆為基準日）
   *
   *  @return  期間損益金額；快照不足兩筆回傳 0
   *
   *  @note    期間損益 = (期末市值 − 期初市值) − 期間淨投入，
   *           基準日當天的現金流不計入（已反映在期初市值中）。
   */
  double CalculatePeriodPnl(List<PortfolioSnapshot> range_snapshots) {
    if (range_snapshots.length < 2) {
      return 0.0;
    }
    final double start_value = range_snapshots.first.total_market_value;
    final double end_value = range_snapshots.last.total_market_value;
    double flows_after_start = 0.0;
    for (int i = 1; i < range_snapshots.length; i++) {
      flows_after_start += range_snapshots[i].net_cash_flow;
    }
    return end_value - start_value - flows_after_start;
  }

  /*
   *  @fn      List<double> CalculateCumulativeReturnPercentSeries(List<PortfolioSnapshot> range_snapshots)
   *
   *  @brief   ( 計算期間內每日的累計時間加權報酬率 %，起點歸零 )
   *
   *  @param   range_snapshots - 期間內的每日快照（第一筆為基準日）
   *
   *  @return  與快照等長的累計報酬率 %（第一筆為 0）
   *
   *  @note    採時間加權法（TWR）：每日報酬
   *           r = (今日市值 − 昨日市值 − 今日淨投入) / (昨日市值 + 今日淨投入)，
   *           假設現金流發生在當日開盤；逐日連乘後轉為 %。
   *           如此新投入的本金不會被誤算成獲利，可與大盤指數公平比較。
   */
  List<double> CalculateCumulativeReturnPercentSeries(
      List<PortfolioSnapshot> range_snapshots) {
    final List<double> percents = <double>[];
    double cumulative_factor = 1.0;
    for (int i = 0; i < range_snapshots.length; i++) {
      if (i > 0) {
        final double previous_value =
            range_snapshots[i - 1].total_market_value;
        final double flow = range_snapshots[i].net_cash_flow;
        final double denominator = previous_value + flow;
        if (denominator > QUANTITY_EPSILON) {
          final double daily_return =
              (range_snapshots[i].total_market_value - previous_value - flow) /
                  denominator;
          cumulative_factor *= (1 + daily_return);
        }
      }
      percents.add((cumulative_factor - 1) * 100);
    }
    return percents;
  }

  /*
   *  @fn      static List<double?> BuildBenchmarkReturnPercentSeries(
   *               Map<int, double> closes_by_date, List<int> dates)
   *
   *  @brief   ( 將大盤指數收盤價對齊組合日期序列，轉為起點歸零的累計報酬率 % )
   *
   *  @param   closes_by_date - {yyyyMMdd: 指數收盤}
   *  @param   dates - 組合曲線的日期序列（含週末）
   *
   *  @return  與 dates 等長；指數尚無資料的日期為 null，
   *           非交易日沿用前一個收盤，以第一個有資料的日期為 0% 基準
   */
  static List<double?> BuildBenchmarkReturnPercentSeries(
      Map<int, double> closes_by_date, List<int> dates) {
    final List<double?> percents = <double?>[];
    double? base_close;
    double? last_close;
    for (final int date in dates) {
      final double? today_close = closes_by_date[date];
      if (today_close != null) {
        last_close = today_close;
        base_close ??= today_close;
      }
      if (base_close == null || last_close == null) {
        percents.add(null);
      } else {
        percents.add((last_close / base_close - 1) * 100);
      }
    }
    return percents;
  }

  /// 依代號分組並依 (trade_date, id) 升冪排序。
  Map<String, List<StockTransaction>> GroupTransactionsBySymbol(
      List<StockTransaction> transactions) {
    final Map<String, List<StockTransaction>> grouped =
        <String, List<StockTransaction>>{};
    for (final StockTransaction tx in transactions) {
      grouped.putIfAbsent(tx.symbol, () => <StockTransaction>[]).add(tx);
    }
    for (final List<StockTransaction> list in grouped.values) {
      list.sort((StockTransaction a, StockTransaction b) {
        final int by_date = a.trade_date.compareTo(b.trade_date);
        if (by_date != 0) {
          return by_date;
        }
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    }
    return grouped;
  }

  /// yyyyMMdd 整數轉 UTC DateTime（僅日期，時間為 00:00）。
  static DateTime ConvertYyyymmddToDateTime(int yyyymmdd) {
    return DateTime.utc(
        yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100);
  }

  /// DateTime 轉 yyyyMMdd 整數。
  static int ConvertDateTimeToYyyymmdd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}

// 投資組合計算引擎：加權平均成本法的持倉彙總，與逐日重播的資產曲線重建。
// 純 Dart 邏輯，不依賴資料庫與網路，方便單元測試。

import 'dart:math' as math;

import '../models/holding_position.dart';
import '../models/portfolio_snapshot.dart';
import '../models/portfolio_risk_metrics.dart';
import '../models/stock_transaction.dart';
import 'market_registry.dart';

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
   *  @fn      static double ConvertCurrencyValue(double value, String from_currency, String display_currency, double usd_twd)
   *
   *  @brief   ( 將 from_currency 金額換算為 display_currency )
   *
   *  @param   value - 原始金額
   *  @param   from_currency - 原始幣別（USD / TWD）
   *  @param   display_currency - 目標顯示幣別（USD / TWD）
   *  @param   usd_twd - 1 美元兌台幣匯率（例如 32.3）
   *
   *  @return  換算後金額
   *
   *  @note    方向：USD→TWD 乘以匯率、TWD→USD 除以匯率、同幣別原值返回。
   *           匯率無效（≤0）時不換算，直接返回原值避免除以零；
   *           同幣別走捷徑不經過任何乘除，確保全美股組合 bit-for-bit 一致。
   */
  static double ConvertCurrencyValue(
    double value,
    String from_currency,
    String display_currency,
    double usd_twd,
  ) {
    if (from_currency == display_currency) {
      return value;
    }
    if (usd_twd <= 0) {
      return value; // 匯率不可用時退回原值（呼叫端會另行降級顯示）
    }
    if (from_currency == 'USD' && display_currency == 'TWD') {
      return value * usd_twd;
    }
    if (from_currency == 'TWD' && display_currency == 'USD') {
      return value / usd_twd;
    }
    return value; // 未知幣別組合：保守返回原值
  }

  /*
   *  @fn      static double ResolveForwardFilledRate(List<int> sorted_dates, Map<int, double> rates, int date)
   *
   *  @brief   ( 往前遞補查詢某日匯率：取 ≤ 該日的最近一筆，皆無更早則取最早一筆 )
   *
   *  @param   sorted_dates - 已升冪排序的匯率日期（yyyyMMdd）
   *  @param   rates - {yyyyMMdd: 1 美元兌台幣}
   *  @param   date - 欲查詢的日期（yyyyMMdd）
   *
   *  @return  遞補後的匯率；rates 為空時回傳 1.0（等同不換算）
   *
   *  @note    週末、假日或未涵蓋的日期沿用前一個已知匯率。
   */
  static double ResolveForwardFilledRate(
    List<int> sorted_dates,
    Map<int, double> rates,
    int date,
  ) {
    if (sorted_dates.isEmpty) {
      return 1.0;
    }
    if (date <= sorted_dates.first) {
      return rates[sorted_dates.first]!;
    }
    double result = rates[sorted_dates.first]!;
    for (final int d in sorted_dates) {
      if (d <= date) {
        result = rates[d]!;
      } else {
        break;
      }
    }
    return result;
  }

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
    List<StockTransaction> transactions,
  ) {
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
          final double average_cost = total_quantity > QUANTITY_EPSILON
              ? total_cost / total_quantity
              : 0.0;
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

      final double average_cost = total_quantity > QUANTITY_EPSILON
          ? total_cost / total_quantity
          : 0.0;
      positions.add(
        HoldingPosition(
          symbol: symbol,
          net_quantity: total_quantity,
          average_cost: average_cost,
          total_cost_basis: total_cost,
          realized_pnl: realized_pnl,
          transactions: symbol_transactions,
        ),
      );
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
   *
   *  @param   display_currency - 顯示幣別（USD / TWD），預設 USD
   *  @param   usd_twd_by_date - {yyyyMMdd: 1 美元兌台幣} 歷史匯率，可為空 map；
   *           缺日以往前遞補處理。全美股且 USD 顯示時不觸發任何換算，
   *           行為與未帶幣別參數時 bit-for-bit 一致。
   */
  List<PortfolioSnapshot> CalculateDailyPortfolioHistory(
    List<StockTransaction> transactions,
    Map<String, Map<int, double>> historical_closes,
    int today_date, {
    String display_currency = 'USD',
    Map<int, double> usd_twd_by_date = const <int, double>{},
  }) {
    if (transactions.isEmpty) {
      return <PortfolioSnapshot>[];
    }

    final Map<String, List<StockTransaction>> grouped =
        GroupTransactionsBySymbol(transactions);

    // 各代號的原生幣別（換算到 display_currency 用）
    final Map<String, String> currency_by_symbol = <String, String>{
      for (final String s in grouped.keys)
        s: ResolveMarketForSymbol(s).currency,
    };
    // 匯率日期預先排序，供逐日往前遞補查詢
    final List<int> sorted_rate_dates = usd_twd_by_date.keys.toList()..sort();

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
      // 當日匯率（往前遞補），供各幣別金額換算到 display_currency
      final double usd_twd = ResolveForwardFilledRate(
        sorted_rate_dates,
        usd_twd_by_date,
        date,
      );

      // 先套用當日全部交易，同時累計當日淨投入現金流（已換算為 display_currency）
      double day_cash_flow = 0.0;
      for (final String symbol in grouped.keys) {
        final String currency = currency_by_symbol[symbol]!;
        final List<StockTransaction> txs = grouped[symbol]!;
        int index = next_tx_index[symbol]!;
        while (index < txs.length && txs[index].trade_date <= date) {
          final StockTransaction tx = txs[index];
          final double quantity = quantity_by_symbol[symbol] ?? 0.0;
          final double cost = cost_by_symbol[symbol] ?? 0.0;
          if (tx.transaction_type == TransactionType.buy) {
            quantity_by_symbol[symbol] = quantity + tx.quantity;
            cost_by_symbol[symbol] = cost + tx.purchase_price * tx.quantity;
            day_cash_flow += ConvertCurrencyValue(
              tx.purchase_price * tx.quantity,
              currency,
              display_currency,
              usd_twd,
            );
            // 尚無歷史價時以買入價當作已知價格起點
            last_known_price.putIfAbsent(symbol, () => tx.purchase_price);
          } else if (tx.quantity <= quantity + QUANTITY_EPSILON) {
            final double average_cost = quantity > QUANTITY_EPSILON
                ? cost / quantity
                : 0.0;
            double new_quantity = quantity - tx.quantity;
            double new_cost = cost - average_cost * tx.quantity;
            if (new_quantity < QUANTITY_EPSILON) {
              new_quantity = 0.0;
              new_cost = 0.0;
            }
            quantity_by_symbol[symbol] = new_quantity;
            cost_by_symbol[symbol] = new_cost;
            day_cash_flow -= ConvertCurrencyValue(
              tx.purchase_price * tx.quantity,
              currency,
              display_currency,
              usd_twd,
            ); // 賣出所得
          }
          index++;
        }
        next_tx_index[symbol] = index;
      }

      // 更新當日已知價格並累計市值與成本（各檔先換算到 display_currency 再加總）
      double total_market_value = 0.0;
      double total_cost_basis = 0.0;
      for (final String symbol in grouped.keys) {
        final String currency = currency_by_symbol[symbol]!;
        final double quantity = quantity_by_symbol[symbol] ?? 0.0;
        final double? today_close = historical_closes[symbol]?[date];
        if (today_close != null) {
          last_known_price[symbol] = today_close;
        }
        if (quantity > QUANTITY_EPSILON) {
          total_market_value += ConvertCurrencyValue(
            quantity * (last_known_price[symbol] ?? 0.0),
            currency,
            display_currency,
            usd_twd,
          );
          total_cost_basis += ConvertCurrencyValue(
            cost_by_symbol[symbol] ?? 0.0,
            currency,
            display_currency,
            usd_twd,
          );
        }
      }

      snapshots.add(
        PortfolioSnapshot(
          date: date,
          total_market_value: total_market_value,
          total_cost_basis: total_cost_basis,
          net_cash_flow: day_cash_flow,
        ),
      );

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
    List<PortfolioSnapshot> range_snapshots,
  ) {
    final List<double> percents = <double>[];
    double cumulative_factor = 1.0;
    for (int i = 0; i < range_snapshots.length; i++) {
      if (i > 0) {
        final double previous_value = range_snapshots[i - 1].total_market_value;
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

  /// 依目前持倉市值與歷史快照計算集中度、最大回撤及年化波動率。
  PortfolioRiskMetrics CalculatePortfolioRiskMetrics(
    List<PortfolioSnapshot> snapshots,
    Map<String, double> market_value_by_symbol,
  ) {
    String? largest_symbol;
    double largest_value = 0.0;
    double total_value = 0.0;
    for (final MapEntry<String, double> entry
        in market_value_by_symbol.entries) {
      if (entry.value <= 0) {
        continue;
      }
      total_value += entry.value;
      if (entry.value > largest_value) {
        largest_value = entry.value;
        largest_symbol = entry.key;
      }
    }
    final double? largest_weight = total_value > QUANTITY_EPSILON
        ? largest_value / total_value * 100
        : null;

    if (snapshots.length < 2) {
      return PortfolioRiskMetrics(
        largest_position_symbol: largest_symbol,
        largest_position_weight_percent: largest_weight,
        maximum_drawdown_percent: null,
        annualized_volatility_percent: null,
      );
    }

    final List<double> daily_returns = <double>[];
    double cumulative_factor = 1.0;
    double peak_factor = 1.0;
    double maximum_drawdown = 0.0;
    for (int i = 1; i < snapshots.length; i++) {
      final PortfolioSnapshot previous = snapshots[i - 1];
      final PortfolioSnapshot current = snapshots[i];
      final double denominator =
          previous.total_market_value + current.net_cash_flow;
      if (denominator <= QUANTITY_EPSILON) {
        continue;
      }
      final double daily_return =
          (current.total_market_value -
              previous.total_market_value -
              current.net_cash_flow) /
          denominator;
      if (!daily_return.isFinite || daily_return <= -1) {
        continue;
      }
      cumulative_factor *= 1 + daily_return;
      peak_factor = math.max(peak_factor, cumulative_factor);
      final double drawdown = cumulative_factor / peak_factor - 1;
      maximum_drawdown = math.min(maximum_drawdown, drawdown);

      final DateTime date = ConvertYyyymmddToDateTime(current.date);
      if (date.weekday <= DateTime.friday) {
        daily_returns.add(daily_return);
      }
    }

    double? annualized_volatility;
    // 至少約一個交易月，避免少量資料顯示沒有代表性的波動率。
    if (daily_returns.length >= 20) {
      final double mean =
          daily_returns.fold<double>(
            0.0,
            (double sum, double value) => sum + value,
          ) /
          daily_returns.length;
      final double variance =
          daily_returns.fold<double>(
            0.0,
            (double sum, double value) => sum + math.pow(value - mean, 2),
          ) /
          (daily_returns.length - 1);
      annualized_volatility = math.sqrt(variance) * math.sqrt(252) * 100;
    }

    return PortfolioRiskMetrics(
      largest_position_symbol: largest_symbol,
      largest_position_weight_percent: largest_weight,
      maximum_drawdown_percent: maximum_drawdown * 100,
      annualized_volatility_percent: annualized_volatility,
    );
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
    Map<int, double> closes_by_date,
    List<int> dates,
  ) {
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

  /*
   *  @fn      Map<String, double> CalculateDividendIncomeBySymbol(
   *               List<StockTransaction> transactions,
   *               Map<String, Map<int, double>> dividend_events)
   *
   *  @brief   ( 計算各代號的累計股息收入：除息日當時持股數 × 每股配息 )
   *
   *  @param   transactions - 全部交易紀錄
   *  @param   dividend_events - {symbol: {除息日: 每股金額}}
   *
   *  @return  {symbol: 累計股息}；除息日前一天須已持有才計入
   *
   *  @note    以「除息日之前（不含當日）的交易」重播出持股數，
   *           因為除息日當天買入的股票領不到該次配息。
   */
  Map<String, double> CalculateDividendIncomeBySymbol(
    List<StockTransaction> transactions,
    Map<String, Map<int, double>> dividend_events,
  ) {
    final Map<String, List<StockTransaction>> grouped =
        GroupTransactionsBySymbol(transactions);
    final Map<String, double> income_by_symbol = <String, double>{};

    for (final MapEntry<String, Map<int, double>> entry
        in dividend_events.entries) {
      final String symbol = entry.key;
      final List<StockTransaction>? txs = grouped[symbol];
      if (txs == null) {
        continue;
      }
      double income = 0.0;
      final List<int> ex_dates = entry.value.keys.toList()..sort();
      for (final int ex_date in ex_dates) {
        double quantity_at_ex_date = 0.0;
        for (final StockTransaction tx in txs) {
          if (tx.trade_date >= ex_date) {
            break; // 已排序，之後的交易都在除息日當天或之後
          }
          quantity_at_ex_date += tx.transaction_type == TransactionType.buy
              ? tx.quantity
              : -tx.quantity;
        }
        if (quantity_at_ex_date > QUANTITY_EPSILON) {
          income += quantity_at_ex_date * entry.value[ex_date]!;
        }
      }
      if (income > 0) {
        income_by_symbol[symbol] = income;
      }
    }
    return income_by_symbol;
  }

  /*
   *  @fn      double? CalculateXirr(List<(int, double)> dated_cashflows)
   *
   *  @brief   ( 計算資金加權年化報酬率 XIRR，二分法求解 )
   *
   *  @param   dated_cashflows - (yyyyMMdd, 現金流) 清單：
   *           買入為負、賣出與股息為正、最後一筆為今日總市值（正）
   *
   *  @return  年化報酬率（0.15 = 15%）；無法求解（現金流同號、
   *           全部同一天、或無收斂）回傳 null
   *
   *  @note    求解 Σ CF_i / (1+r)^(d_i/365) = 0，r 搜尋範圍 (-0.99, 10)。
   */
  double? CalculateXirr(List<(int, double)> dated_cashflows) {
    if (dated_cashflows.length < 2) {
      return null;
    }
    final bool has_negative = dated_cashflows.any(
      ((int, double) cf) => cf.$2 < 0,
    );
    final bool has_positive = dated_cashflows.any(
      ((int, double) cf) => cf.$2 > 0,
    );
    if (!has_negative || !has_positive) {
      return null;
    }

    final DateTime first_date = ConvertYyyymmddToDateTime(
      dated_cashflows
          .map(((int, double) cf) => cf.$1)
          .reduce((int a, int b) => a < b ? a : b),
    );

    // 現金流淨現值函數
    double EvaluateNetPresentValue(double rate) {
      double total = 0.0;
      for (final (int, double) cf in dated_cashflows) {
        final double years =
            ConvertYyyymmddToDateTime(cf.$1).difference(first_date).inDays /
            365.0;
        total += cf.$2 / _Power(1 + rate, years);
      }
      return total;
    }

    double low = -0.99;
    double high = 10.0;
    double npv_low = EvaluateNetPresentValue(low);
    final double npv_high = EvaluateNetPresentValue(high);
    if (npv_low.isNaN || npv_high.isNaN || npv_low * npv_high > 0) {
      return null; // 兩端同號，無解（例如全部現金流在同一天）
    }
    for (int i = 0; i < 200; i++) {
      final double mid = (low + high) / 2;
      final double npv_mid = EvaluateNetPresentValue(mid);
      if (npv_mid.abs() < 1e-9) {
        return mid;
      }
      if (npv_low * npv_mid < 0) {
        high = mid;
      } else {
        low = mid;
        npv_low = npv_mid;
      }
    }
    return (low + high) / 2;
  }

  /// 實數次方（底數必為正，供折現計算）。
  static double _Power(double base, double exponent) {
    if (base <= 0) {
      return double.nan;
    }
    return math.pow(base, exponent).toDouble();
  }

  /// 依代號分組並依 (trade_date, id) 升冪排序。
  Map<String, List<StockTransaction>> GroupTransactionsBySymbol(
    List<StockTransaction> transactions,
  ) {
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
      yyyymmdd ~/ 10000,
      (yyyymmdd ~/ 100) % 100,
      yyyymmdd % 100,
    );
  }

  /// DateTime 轉 yyyyMMdd 整數。
  static int ConvertDateTimeToYyyymmdd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}

// 單一股票代號的持倉彙總結果（加權平均法）。

import 'stock_transaction.dart';

/*
 * @author Toby
 * @date 2026/07/11
 * @class HoldingPosition
 * @brief 以加權平均成本法算出的單檔持倉結果。
 * @note net_quantity 為 0 時仍保留此物件（顯示已實現損益），並以 is_closed 標記。
 */
class HoldingPosition {
  final String symbol; // 股票代號
  final double net_quantity; // 目前淨持有數量
  final double average_cost; // 加權平均成本（每股）
  final double total_cost_basis; // 目前持倉成本總額 = average_cost * net_quantity
  final double realized_pnl; // 累計已實現損益
  final List<StockTransaction> transactions; // 構成此持倉的交易明細（已排序）

  const HoldingPosition({
    required this.symbol,
    required this.net_quantity,
    required this.average_cost,
    required this.total_cost_basis,
    required this.realized_pnl,
    required this.transactions,
  });

  /// 是否已清倉（淨持有量趨近於 0）。
  bool get is_closed => net_quantity.abs() < 1e-9;

  @override
  String toString() {
    return 'HoldingPosition($symbol, qty=$net_quantity, '
        'avg=$average_cost, realized=$realized_pnl, closed=$is_closed)';
  }
}

// 資產曲線中「某一天」的投資組合快照。

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   PortfolioSnapshot
 *
 * @brief   資產曲線上單一日期的市值、成本與當日淨投入現金流。
 *
 * @note    date 使用 yyyyMMdd 整數格式；net_cash_flow 為當日
 *          「買入金額 − 賣出所得」，期間損益與時間加權報酬率
 *          都需要用它排除本金進出的影響。
 */
class PortfolioSnapshot {
  final int date; // 日期 yyyyMMdd
  final double total_market_value; // 當日總市值
  final double total_cost_basis; // 當日累計投入成本
  final double net_cash_flow; // 當日淨投入（買入金額 − 賣出所得）

  const PortfolioSnapshot({
    required this.date,
    required this.total_market_value,
    required this.total_cost_basis,
    this.net_cash_flow = 0.0,
  });

  @override
  String toString() {
    return 'PortfolioSnapshot($date, mv=$total_market_value, '
        'cost=$total_cost_basis, flow=$net_cash_flow)';
  }
}

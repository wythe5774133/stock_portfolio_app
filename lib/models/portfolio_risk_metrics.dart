// 投資組合風險摘要：集中度、最大回撤與年化波動率。

class PortfolioRiskMetrics {
  final String? largest_position_symbol; // 最大持倉代號
  final double? largest_position_weight_percent; // 最大持倉占總市值比例
  final double? maximum_drawdown_percent; // 歷史高點至低點的最大跌幅
  final double? annualized_volatility_percent; // 日報酬標準差年化

  const PortfolioRiskMetrics({
    required this.largest_position_symbol,
    required this.largest_position_weight_percent,
    required this.maximum_drawdown_percent,
    required this.annualized_volatility_percent,
  });
}

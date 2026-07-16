// 投資組合風險卡片：以集中度、最大回撤與年化波動率提示組合風險。

import 'package:flutter/material.dart';

import '../../models/portfolio_risk_metrics.dart';
import '../theme/app_theme.dart';

class PortfolioRiskCard extends StatelessWidget {
  final PortfolioRiskMetrics metrics;

  const PortfolioRiskCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double item_width = constraints.maxWidth < 620
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _BuildMetric(
              colors,
              item_width,
              '最大持倉',
              metrics.largest_position_weight_percent == null
                  ? '—'
                  : '${metrics.largest_position_weight_percent!.toStringAsFixed(1)}%',
              metrics.largest_position_symbol ?? '尚無持倉',
            ),
            _BuildMetric(
              colors,
              item_width,
              '最大回撤',
              metrics.maximum_drawdown_percent == null
                  ? '—'
                  : '${metrics.maximum_drawdown_percent!.toStringAsFixed(1)}%',
              '所選期間高點至低點',
            ),
            _BuildMetric(
              colors,
              item_width,
              '年化波動率',
              metrics.annualized_volatility_percent == null
                  ? '—'
                  : '${metrics.annualized_volatility_percent!.toStringAsFixed(1)}%',
              metrics.annualized_volatility_percent == null
                  ? '至少需要 20 個交易日'
                  : '依每日報酬年化',
            ),
          ],
        );
      },
    );
  }

  /// 建立單一風險指標區塊。
  Widget _BuildMetric(
    AppColors colors,
    double width,
    String label,
    String value,
    String description,
  ) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.subtle_background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.text_secondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: colors.text_primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: colors.text_muted),
          ),
        ],
      ),
    );
  }
}

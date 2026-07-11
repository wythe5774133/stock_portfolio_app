// 儀表板頂端統計卡片：總資產（含今日損益）、總成本、未實現損益、
// 已實現損益、累計股息、年化報酬率（XIRR）。深淺主題自動適應。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SummaryStatCards
 *
 * @brief   六張統計卡片以 Wrap 排版自動換行；損益類數字依配色慣例上色。
 */
class SummaryStatCards extends StatelessWidget {
  final double total_market_value;
  final double total_cost_basis;
  final double total_unrealized_pnl;
  final double total_unrealized_pnl_percent;
  final double total_realized_pnl;
  final double total_day_pnl;
  final double total_day_change_percent;
  final double total_dividend_income;
  final double? portfolio_xirr; // null = 資料不足
  final bool show_dividend_card; // 股息追蹤關閉時隱藏股息卡片
  final ProfitColorScheme profit_colors;

  const SummaryStatCards({
    super.key,
    required this.total_market_value,
    required this.total_cost_basis,
    required this.total_unrealized_pnl,
    required this.total_unrealized_pnl_percent,
    required this.total_realized_pnl,
    required this.total_day_pnl,
    required this.total_day_change_percent,
    required this.total_dividend_income,
    required this.portfolio_xirr,
    required this.show_dividend_card,
    required this.profit_colors,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final String unrealized_sign = total_unrealized_pnl >= 0 ? '+' : '';
    final String realized_sign = total_realized_pnl >= 0 ? '+' : '';
    final String day_sign = total_day_pnl >= 0 ? '+' : '';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 依可用寬度決定每列卡片數：寬 → 一列排滿，窄 → 自動換行
        final int card_count = show_dividend_card ? 6 : 5;
        final double card_width = constraints.maxWidth >= 1080
            ? (constraints.maxWidth - (card_count - 1) * 12) / card_count
            : constraints.maxWidth >= 700
                ? (constraints.maxWidth - 2 * 12) / 3
                : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _BuildStatCard(
              colors: colors,
              width: card_width,
              title: '總資產',
              value: money.format(total_market_value),
              subtitle: '今日 $day_sign${money.format(total_day_pnl)}'
                  '（$day_sign${total_day_change_percent.toStringAsFixed(2)}%）',
              subtitle_color:
                  profit_colors.ResolveColorForValue(total_day_pnl),
            ),
            _BuildStatCard(
              colors: colors,
              width: card_width,
              title: '總成本',
              value: money.format(total_cost_basis),
            ),
            _BuildStatCard(
              colors: colors,
              width: card_width,
              title: '未實現損益',
              value: '$unrealized_sign${money.format(total_unrealized_pnl)}',
              subtitle:
                  '$unrealized_sign${total_unrealized_pnl_percent.toStringAsFixed(2)}%',
              value_color:
                  profit_colors.ResolveColorForValue(total_unrealized_pnl),
              subtitle_color:
                  profit_colors.ResolveColorForValue(total_unrealized_pnl),
            ),
            _BuildStatCard(
              colors: colors,
              width: card_width,
              title: '已實現損益',
              value: '$realized_sign${money.format(total_realized_pnl)}',
              value_color:
                  profit_colors.ResolveColorForValue(total_realized_pnl),
            ),
            if (show_dividend_card)
              _BuildStatCard(
                colors: colors,
                width: card_width,
                title: '累計股息',
                value: money.format(total_dividend_income),
                subtitle: '依除息日持股計算',
              ),
            _BuildStatCard(
              colors: colors,
              width: card_width,
              title: '年化報酬率 XIRR',
              value: portfolio_xirr != null
                  ? '${portfolio_xirr! >= 0 ? '+' : ''}'
                      '${(portfolio_xirr! * 100).toStringAsFixed(2)}%'
                  : '—',
              subtitle: show_dividend_card ? '資金加權・含股息' : '資金加權',
              value_color: portfolio_xirr != null
                  ? profit_colors.ResolveColorForValue(portfolio_xirr!)
                  : null,
            ),
          ],
        );
      },
    );
  }

  /// 單張統計卡片。
  Widget _BuildStatCard({
    required AppColors colors,
    required double width,
    required String title,
    required String value,
    String? subtitle,
    Color? value_color,
    Color? subtitle_color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(fontSize: 13, color: colors.text_secondary),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: value_color ?? colors.text_primary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: subtitle_color ?? colors.text_muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

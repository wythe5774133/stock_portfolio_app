// 儀表板頂端統計卡片列：總資產、總成本、未實現損益、已實現損益。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SummaryStatCards
 *
 * @brief   四張統計卡片：總資產、總成本、未實現損益（金額+%）、已實現損益。
 *          損益卡片顏色依配色慣例（美股/台股）切換。
 */
class SummaryStatCards extends StatelessWidget {
  final double total_market_value;
  final double total_cost_basis;
  final double total_unrealized_pnl;
  final double total_unrealized_pnl_percent;
  final double total_realized_pnl;
  final ProfitColorScheme profit_colors;

  const SummaryStatCards({
    super.key,
    required this.total_market_value,
    required this.total_cost_basis,
    required this.total_unrealized_pnl,
    required this.total_unrealized_pnl_percent,
    required this.total_realized_pnl,
    required this.profit_colors,
  });

  @override
  Widget build(BuildContext context) {
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final String sign = total_unrealized_pnl >= 0 ? '+' : '';
    final String realized_sign = total_realized_pnl >= 0 ? '+' : '';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool is_narrow = constraints.maxWidth < 760;
        final List<Widget> cards = <Widget>[
          _BuildStatCard(
            title: '總資產',
            value: money.format(total_market_value),
            value_color: null,
          ),
          _BuildStatCard(
            title: '總成本',
            value: money.format(total_cost_basis),
            value_color: null,
          ),
          _BuildStatCard(
            title: '未實現損益',
            value: '$sign${money.format(total_unrealized_pnl)}',
            subtitle:
                '$sign${total_unrealized_pnl_percent.toStringAsFixed(2)}%',
            value_color:
                profit_colors.ResolveColorForValue(total_unrealized_pnl),
          ),
          _BuildStatCard(
            title: '已實現損益',
            value: '$realized_sign${money.format(total_realized_pnl)}',
            value_color:
                profit_colors.ResolveColorForValue(total_realized_pnl),
          ),
        ];

        if (is_narrow) {
          return Column(
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ]),
              const SizedBox(height: 12),
              Row(children: <Widget>[
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ]),
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  /// 單張統計卡片。
  Widget _BuildStatCard({
    required String title,
    required String value,
    String? subtitle,
    Color? value_color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: value_color ?? const Color(0xFF111827),
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value_color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 個股持倉列表：每列可點擊展開，顯示該股票的全部交易明細。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stock_transaction.dart';
import '../dashboard_controller.dart';
import '../theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HoldingListView
 *
 * @brief   持倉列表：代號、股數、均價、現價（含來源標示）、市值、未實現損益，
 *          點擊展開顯示逐筆交易明細與已實現損益。
 */
class HoldingListView extends StatelessWidget {
  final List<HoldingDisplayRow> rows;
  final ProfitColorScheme profit_colors;

  const HoldingListView({
    super.key,
    required this.rows,
    required this.profit_colors,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('尚無持倉，請先匯入交易紀錄 CSV',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: <Widget>[
        _BuildHeaderRow(),
        const Divider(height: 1, color: Color(0xFFE8EAEE)),
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const Divider(height: 1, color: Color(0xFFF0F1F4)),
          _HoldingExpandableRow(row: rows[i], profit_colors: profit_colors),
        ],
      ],
    );
  }

  /// 表頭列。
  Widget _BuildHeaderRow() {
    const TextStyle header_style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280),
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text('代號', style: header_style)),
          Expanded(
              flex: 3,
              child: Text('持股', style: header_style,
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 3,
              child: Text('均價', style: header_style,
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 3,
              child: Text('現價', style: header_style,
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 4,
              child: Text('市值', style: header_style,
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 4,
              child: Text('未實現損益', style: header_style,
                  textAlign: TextAlign.right)),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

/// 單一持倉的可展開列。
class _HoldingExpandableRow extends StatelessWidget {
  final HoldingDisplayRow row;
  final ProfitColorScheme profit_colors;

  const _HoldingExpandableRow({
    required this.row,
    required this.profit_colors,
  });

  @override
  Widget build(BuildContext context) {
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final Color pnl_color =
        profit_colors.ResolveColorForValue(row.unrealized_pnl);
    final String sign = row.unrealized_pnl >= 0 ? '+' : '';

    return Theme(
      // 移除 ExpansionTile 展開時的上下分隔線，維持列表乾淨
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const Border(),
        title: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                row.position.symbol,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                FormatQuantity(row.position.net_quantity),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                money.format(row.position.average_cost),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    row.current_price != null
                        ? money.format(row.current_price)
                        : '—',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    row.price_source_label,
                    style:
                        const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                money.format(row.market_value),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '$sign${money.format(row.unrealized_pnl)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: pnl_color,
                    ),
                  ),
                  Text(
                    '$sign${row.unrealized_pnl_percent.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 11.5, color: pnl_color),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: <Widget>[
          _BuildTransactionDetail(),
        ],
      ),
    );
  }

  /// 展開後的交易明細區塊。
  Widget _BuildTransactionDetail() {
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final List<StockTransaction> transactions = row.position.transactions;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '交易明細（${transactions.length} 筆）',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280)),
              ),
              const Spacer(),
              Text(
                '已實現損益 '
                '${row.position.realized_pnl >= 0 ? '+' : ''}'
                '${money.format(row.position.realized_pnl)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: profit_colors
                      .ResolveColorForValue(row.position.realized_pnl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final StockTransaction tx in transactions.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  _BuildTypeBadge(tx.transaction_type),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text(
                      FormatTradeDate(tx.trade_date),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${FormatQuantity(tx.quantity)} 股 × '
                      '${money.format(tx.purchase_price)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    money.format(tx.purchase_price * tx.quantity),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// BUY / SELL 徽章。
  Widget _BuildTypeBadge(TransactionType type) {
    final bool is_buy = type == TransactionType.buy;
    final Color color =
        is_buy ? const Color(0xFF4F6DF5) : const Color(0xFFD97706);
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        is_buy ? '買入' : '賣出',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  /// 股數顯示：整數不帶小數，碎股最多 5 位小數並去尾零。
  static String FormatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity
        .toStringAsFixed(5)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// yyyyMMdd 轉 yyyy/MM/dd。
  static String FormatTradeDate(int yyyymmdd) {
    final int year = yyyymmdd ~/ 10000;
    final int month = (yyyymmdd ~/ 100) % 100;
    final int day = yyyymmdd % 100;
    return '$year/${month.toString().padLeft(2, '0')}/'
        '${day.toString().padLeft(2, '0')}';
  }
}

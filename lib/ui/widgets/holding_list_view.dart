// 個股持倉列表：寬螢幕完整六欄、窄螢幕（手機）緊湊三欄，
// 每列可點擊展開顯示交易明細。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stock_transaction.dart';
import '../dashboard_controller.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';
import '../theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HoldingListView
 *
 * @brief   持倉列表：桌面顯示代號/持股/均價/現價/市值/未實現損益六欄，
 *          手機縮為代號+持股/現價+今日/損益三欄；展開顯示逐筆交易、
 *          均價市值補充資訊與個股詳情入口。
 */
class HoldingListView extends StatelessWidget {
  /// 低於此寬度改用手機緊湊排版
  static const double COMPACT_BREAKPOINT = 640;

  final List<HoldingDisplayRow> rows;
  final ProfitColorScheme profit_colors;
  final DashboardController controller;

  const HoldingListView({
    super.key,
    required this.rows,
    required this.profit_colors,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('尚無持倉，匯入交易 CSV 或點「記一筆」開始',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final AppColors colors = AppColors.Of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool is_compact = constraints.maxWidth < COMPACT_BREAKPOINT;
        return Column(
          children: <Widget>[
            _BuildHeaderRow(context, is_compact),
            Divider(height: 1, color: colors.card_border),
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: colors.divider),
              _HoldingExpandableRow(
                row: rows[i],
                profit_colors: profit_colors,
                controller: controller,
                is_compact: is_compact,
              ),
            ],
          ],
        );
      },
    );
  }

  /// 表頭列（依寬度切換欄位組）。
  Widget _BuildHeaderRow(BuildContext context, bool is_compact) {
    final TextStyle header_style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.Of(context).text_secondary,
    );
    final List<Widget> cells = is_compact
        ? <Widget>[
            Expanded(flex: 4, child: Text('代號／持股', style: header_style)),
            Expanded(
                flex: 4,
                child: Text('現價／今日', style: header_style,
                    textAlign: TextAlign.right)),
            Expanded(
                flex: 4,
                child: Text('未實現損益', style: header_style,
                    textAlign: TextAlign.right)),
          ]
        : <Widget>[
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
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: <Widget>[
        ...cells,
        const SizedBox(width: 32),
      ]),
    );
  }
}

/// 單一持倉的可展開列。
class _HoldingExpandableRow extends StatelessWidget {
  final HoldingDisplayRow row;
  final ProfitColorScheme profit_colors;
  final DashboardController controller;
  final bool is_compact;

  const _HoldingExpandableRow({
    required this.row,
    required this.profit_colors,
    required this.controller,
    required this.is_compact,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // 移除 ExpansionTile 展開時的上下分隔線，維持列表乾淨
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const Border(),
        title: is_compact ? _BuildCompactTitle(context) : _BuildWideTitle(),
        children: <Widget>[
          _BuildTransactionDetail(),
        ],
      ),
    );
  }

  /// 手機緊湊列：代號+持股 / 現價+今日漲跌 / 損益。
  Widget _BuildCompactTitle(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final Color pnl_color =
        profit_colors.ResolveColorForValue(row.unrealized_pnl);
    final String sign = row.unrealized_pnl >= 0 ? '+' : '';

    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(row.position.symbol,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                '${FormatQuantity(row.position.net_quantity)} 股',
                style: TextStyle(fontSize: 11, color: colors.text_muted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
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
                row.day_change_percent != null
                    ? '${row.day_change_percent! >= 0 ? '+' : ''}'
                        '${row.day_change_percent!.toStringAsFixed(2)}%'
                    : row.price_source_label,
                style: TextStyle(
                  fontSize: 11,
                  color: row.day_change_percent != null
                      ? profit_colors
                          .ResolveColorForValue(row.day_change_percent!)
                      : colors.text_muted,
                ),
              ),
            ],
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
                style: TextStyle(fontSize: 11, color: pnl_color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 桌面完整六欄列。
  Widget _BuildWideTitle() {
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final Color pnl_color =
        profit_colors.ResolveColorForValue(row.unrealized_pnl);
    final String sign = row.unrealized_pnl >= 0 ? '+' : '';

    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(
            row.position.symbol,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                row.day_change_percent != null
                    ? '${row.price_source_label}・今日 '
                        '${row.day_change_percent! >= 0 ? '+' : ''}'
                        '${row.day_change_percent!.toStringAsFixed(2)}%'
                    : row.price_source_label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: row.day_change_percent != null
                      ? profit_colors
                          .ResolveColorForValue(row.day_change_percent!)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            money.format(row.market_value),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    );
  }

  /// 展開後的交易明細區塊。
  Widget _BuildTransactionDetail() {
    final NumberFormat money = NumberFormat.currency(symbol: r'$');
    final List<StockTransaction> transactions = row.position.transactions;

    return Builder(builder: (BuildContext context) {
      final AppColors colors = AppColors.Of(context);
      return Container(
        decoration: BoxDecoration(
          color: colors.subtle_background,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 標題列用 Wrap，手機窄度不會爆版
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '交易明細（${transactions.length} 筆）',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text_secondary),
                ),
                if (is_compact)
                  Text(
                    '均價 ${money.format(row.position.average_cost)}・'
                    '市值 ${money.format(row.market_value)}',
                    style: TextStyle(
                        fontSize: 12, color: colors.text_secondary),
                  ),
                if (row.dividend_income > 0)
                  Text(
                    '累計股息 +${money.format(row.dividend_income)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text_secondary,
                    ),
                  ),
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
                TextButton.icon(
                  onPressed: () => StockDetailPage.Open(context, controller,
                      row.position.symbol, row.position.symbol),
                  icon:
                      const Icon(Icons.candlestick_chart_outlined, size: 15),
                  label:
                      const Text('個股詳情', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        overflow: TextOverflow.ellipsis,
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
    });
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

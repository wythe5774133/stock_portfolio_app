// 個股持倉列表：寬螢幕完整六欄、窄螢幕（手機）緊湊三欄，
// 每列可點擊展開顯示交易明細。

import 'package:flutter/material.dart';

import '../../models/stock_transaction.dart';
import '../dashboard_controller.dart';
import '../money_format.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';
import '../theme/profit_color_scheme.dart';
import 'change_percent_badge.dart';
import 'earnings_calendar_card.dart';

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
    // 依市場分組（保留原有市值降序）：同時存在美股與台股才分區顯示節標題
    final Map<String, List<HoldingDisplayRow>> groups = GroupRowsByMarket(rows);
    final bool show_group_headers = groups.length > 1;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool is_compact = constraints.maxWidth < COMPACT_BREAKPOINT;
        final List<Widget> children = <Widget>[
          _BuildHeaderRow(context, is_compact),
          Divider(height: 1, color: colors.card_border),
        ];
        for (final MapEntry<String, List<HoldingDisplayRow>> group
            in groups.entries) {
          if (show_group_headers) {
            children.add(
              _BuildGroupHeader(colors, group.value.first.market.market_label),
            );
          }
          for (int i = 0; i < group.value.length; i++) {
            // 群組內列與列之間才畫分隔線，節標題下方不畫
            if (i > 0) {
              children.add(Divider(height: 1, color: colors.divider));
            }
            children.add(_HoldingExpandableRow(
              row: group.value[i],
              profit_colors: profit_colors,
              controller: controller,
              is_compact: is_compact,
            ));
          }
        }
        return Column(children: children);
      },
    );
  }

  /*
   *  @fn      static Map<String, List<HoldingDisplayRow>> GroupRowsByMarket(List<HoldingDisplayRow> rows)
   *
   *  @brief   ( 依市場代號穩定分組，保留傳入的市值降序 )
   *
   *  @param   rows - 已排序的持倉顯示列
   *
   *  @return  market_id → 該市場的列（依首次出現順序）
   *
   *  @note    Dart Map 保留插入順序，故群組順序即各市場首檔的出現順序。
   */
  static Map<String, List<HoldingDisplayRow>> GroupRowsByMarket(
    List<HoldingDisplayRow> rows,
  ) {
    final Map<String, List<HoldingDisplayRow>> groups =
        <String, List<HoldingDisplayRow>>{};
    for (final HoldingDisplayRow row in rows) {
      groups.putIfAbsent(row.market.market_id, () => <HoldingDisplayRow>[])
          .add(row);
    }
    return groups;
  }

  /// 市場分區的低調節標題（「美股」／「台股」）。
  Widget _BuildGroupHeader(AppColors colors, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.text_secondary,
          ),
        ),
      ),
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
            Expanded(flex: 5, child: Text('代號／持股', style: header_style)),
            Expanded(
                flex: 6,
                child: Text('現價／今日／損益', style: header_style,
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

  /// 手機緊湊列：左為代號+持股，右側垂直堆疊現價／當日漲跌色塊／未實現損益。
  Widget _BuildCompactTitle(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final String currency = row.market.currency;
    final Color pnl_color =
        profit_colors.ResolveColorForValue(row.unrealized_pnl);
    final Color day_change_color = row.day_change_percent != null
        ? profit_colors.ResolveColorForValue(row.day_change_percent!)
        : colors.text_muted;
    final String sign = row.unrealized_pnl >= 0 ? '+' : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BuildSymbolWithBadge(
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${FormatQuantity(row.position.net_quantity)} 股',
                style: TextStyle(fontSize: 11.5, color: colors.text_muted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _BuildSingleLineText(
                row.current_price != null
                    ? FormatMoney(row.current_price!, currency)
                    : '—',
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              ChangePercentBadge(
                percent: row.day_change_percent,
                color: day_change_color,
              ),
              const SizedBox(height: 3),
              // 未實現損益一行呈現金額與百分比，色走 profit_colors（不用色塊）
              _BuildSingleLineText(
                '$sign${FormatMoney(row.unrealized_pnl, currency)} '
                '($sign${row.unrealized_pnl_percent.toStringAsFixed(2)}%)',
                TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: pnl_color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 代號＋（7 天內有財報時）財報倒數標籤。
  Widget _BuildSymbolWithBadge(TextStyle style) {
    final Widget? badge = BuildEarningsBadge(controller, row.position.symbol);
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            row.position.symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (badge != null) ...<Widget>[
          const SizedBox(width: 6),
          badge,
        ],
      ],
    );
  }

  /// 單行文字：過長時等比例縮小而非換行（手機數字防跑版）。
  static Widget _BuildSingleLineText(String text, TextStyle style) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, maxLines: 1, style: style),
    );
  }

  /// 桌面完整六欄列。
  Widget _BuildWideTitle() {
    final String currency = row.market.currency;
    final Color pnl_color =
        profit_colors.ResolveColorForValue(row.unrealized_pnl);
    final String sign = row.unrealized_pnl >= 0 ? '+' : '';

    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _BuildSymbolWithBadge(
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
            FormatMoney(row.position.average_cost, currency),
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
                    ? FormatMoney(row.current_price!, currency)
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
            FormatMoney(row.market_value, currency),
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
                '$sign${FormatMoney(row.unrealized_pnl, currency)}',
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
    final String currency = row.market.currency;
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
                    '均價 ${FormatMoney(row.position.average_cost, currency)}・'
                    '市值 ${FormatMoney(row.market_value, currency)}',
                    style: TextStyle(
                        fontSize: 12, color: colors.text_secondary),
                  ),
                if (row.dividend_income > 0)
                  Text(
                    '累計股息 +${FormatMoney(row.dividend_income, currency)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text_secondary,
                    ),
                  ),
                Text(
                  '已實現損益 '
                  '${row.position.realized_pnl >= 0 ? '+' : ''}'
                  '${FormatMoney(row.position.realized_pnl, currency)}',
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
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    _BuildTypeBadge(tx.transaction_type),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: is_compact ? 52 : 90,
                      child: Text(
                        is_compact
                            ? FormatShortTradeDate(tx.trade_date)
                            : FormatTradeDate(tx.trade_date),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${FormatQuantity(tx.quantity)} 股 × '
                        '${FormatMoney(tx.purchase_price, currency)}',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      FormatMoney(tx.purchase_price * tx.quantity, currency),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      tooltip: '刪除這筆交易',
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      color: colors.text_muted,
                      onPressed: () => _ConfirmAndDeleteTransaction(
                          context, tx),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  /*
   *  @fn      Future<void> _ConfirmAndDeleteTransaction(BuildContext context, StockTransaction tx)
   *
   *  @brief   ( 刪除交易前先確認，刪除後以 SnackBar 回報 )
   *
   *  @note    刪除會即時重算持倉、資產曲線與損益。
   */
  Future<void> _ConfirmAndDeleteTransaction(
      BuildContext context, StockTransaction tx) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('刪除交易',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          '確定刪除這筆交易嗎？\n\n'
          '${tx.symbol}　${FormatTradeDate(tx.trade_date)}　'
          '${tx.transaction_type == TransactionType.buy ? '買入' : '賣出'} '
          '${FormatQuantity(tx.quantity)} 股 × '
          '${FormatMoney(tx.purchase_price, row.market.currency)}\n\n'
          '刪除後持倉與損益會立即重算，此動作無法復原。',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || tx.id == null) {
      return;
    }
    await controller.DeleteTransaction(tx);
    messenger.showSnackBar(const SnackBar(content: Text('交易已刪除，持倉已重算')));
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

  /// yyyyMMdd 轉 MM/dd（窄螢幕交易列用，年份看完整明細）。
  static String FormatShortTradeDate(int yyyymmdd) {
    final int month = (yyyymmdd ~/ 100) % 100;
    final int day = yyyymmdd % 100;
    return '${month.toString().padLeft(2, '0')}/'
        '${day.toString().padLeft(2, '0')}';
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

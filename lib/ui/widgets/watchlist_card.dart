// 自選股追蹤清單卡片：現價與今日漲跌，點列進入個股詳情頁。

import 'package:flutter/material.dart';

import '../../database/app_database.dart' show WatchlistSymbol;
import '../../models/stock_quote.dart';
import '../dashboard_controller.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   WatchlistCard
 *
 * @brief   追蹤清單：每列顯示代號、名稱、現價、今日漲跌%（配色慣例上色），
 *          點列開詳情頁、hover 顯示移除按鈕。
 */
class WatchlistCard extends StatelessWidget {
  final DashboardController controller;

  const WatchlistCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    if (controller.watchlist.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Text(
          '尚無追蹤股票，點右上角「＋追蹤」加入（不需要持有）',
          style: TextStyle(fontSize: 13, color: colors.text_muted),
        ),
      );
    }

    final Map<String, StockQuote> quotes =
        controller.repository.quote_scheduler.latest_quotes;

    return Column(
      children: <Widget>[
        for (int i = 0; i < controller.watchlist.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: colors.divider),
          _BuildWatchlistRow(
              context, controller.watchlist[i], quotes, colors),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  /// 單一追蹤列。
  Widget _BuildWatchlistRow(BuildContext context, WatchlistSymbol entry,
      Map<String, StockQuote> quotes, AppColors colors) {
    final StockQuote? quote = quotes[entry.symbol];
    final (double?, String) price_and_label =
        DashboardController.ResolveDisplayPrice(
            quote, controller.current_session);
    double? change_percent;
    if (quote?.regular_price != null && quote?.previous_close != null) {
      change_percent = (quote!.regular_price! - quote.previous_close!) /
          quote.previous_close! *
          100;
    }
    final Color change_color = change_percent != null
        ? controller.profit_colors.ResolveColorForValue(change_percent)
        : colors.text_secondary;

    return InkWell(
      onTap: () => StockDetailPage.Open(
          context, controller, entry.symbol, entry.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry.symbol,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.text_muted),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    price_and_label.$1 != null
                        ? '\$${price_and_label.$1!.toStringAsFixed(2)}'
                        : '—',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  Text(price_and_label.$2,
                      style: TextStyle(
                          fontSize: 10.5, color: colors.text_muted)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                change_percent != null
                    ? '${change_percent >= 0 ? '+' : ''}'
                        '${change_percent.toStringAsFixed(2)}%'
                    : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: change_color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: '移除追蹤',
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              color: colors.text_muted,
              onPressed: () => controller.RemoveFromWatchlist(entry.symbol),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

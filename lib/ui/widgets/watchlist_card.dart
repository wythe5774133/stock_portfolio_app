// 自選股追蹤清單：分類 chips 過濾、現價與今日漲跌，
// 點列進入個股詳情頁，選單可更改分類或移除。

import 'package:flutter/material.dart';

import '../../database/app_database.dart' show WatchlistSymbol;
import '../../logic/market_registry.dart';
import '../../models/stock_quote.dart';
import '../dashboard_controller.dart';
import '../money_format.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   WatchlistCard
 *
 * @brief   追蹤清單：頂部分類 chips（全部＋各分類），
 *          每列顯示代號/名稱、現價（不換行）、今日漲跌%，
 *          右側選單提供更改分類與移除。
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

    final List<String> groups = controller.GetWatchlistGroups();
    final List<WatchlistSymbol> filtered = controller.GetFilteredWatchlist();
    final Map<String, StockQuote> quotes =
        controller.repository.quote_scheduler.latest_quotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 分類 chips（超過一個分類才顯示）
        if (groups.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Wrap(
              spacing: 6,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('全部', style: TextStyle(fontSize: 12)),
                  selected: controller.selected_watchlist_group == null,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (bool selected) {
                    controller.SwitchWatchlistGroup(null);
                  },
                ),
                for (final String group in groups)
                  ChoiceChip(
                    label: Text(group, style: const TextStyle(fontSize: 12)),
                    selected: controller.selected_watchlist_group == group,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (bool selected) {
                      controller.SwitchWatchlistGroup(group);
                    },
                  ),
              ],
            ),
          ),
        for (int i = 0; i < filtered.length; i++) ...<Widget>[
          if (i > 0) Divider(height: 1, color: colors.divider),
          _BuildWatchlistRow(context, filtered[i], quotes, colors),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  /// 單一追蹤列。
  Widget _BuildWatchlistRow(BuildContext context, WatchlistSymbol entry,
      Map<String, StockQuote> quotes, AppColors colors) {
    final StockQuote? quote = quotes[entry.symbol];
    final MarketInfo market = ResolveMarketForSymbol(entry.symbol);
    final (double?, String) price_and_label =
        DashboardController.ResolveDisplayPrice(
            quote, controller.SessionForMarket(market.market_id), market);
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
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: <Widget>[
            // 代號與名稱
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(entry.symbol,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                      // 台股加低調市場標籤；美股不加，避免雜訊
                      if (market.market_id == 'tw') ...<Widget>[
                        const SizedBox(width: 6),
                        _BuildMarketBadge(market.market_label, colors),
                      ],
                    ],
                  ),
                  Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.text_muted),
                  ),
                ],
              ),
            ),
            // 現價（單行不換行，過長自動縮字）
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      price_and_label.$1 != null
                          ? FormatMoney(price_and_label.$1!, market.currency)
                          : '—',
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                      price_and_label.$1 != null
                          ? price_and_label.$2
                          : '無報價',
                      style: TextStyle(
                          fontSize: 10.5, color: colors.text_muted)),
                ],
              ),
            ),
            // 今日漲跌 %
            Expanded(
              flex: 6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  change_percent != null
                      ? '${change_percent >= 0 ? '+' : ''}'
                          '${change_percent.toStringAsFixed(2)}%'
                      : '—',
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: change_color,
                  ),
                ),
              ),
            ),
            // 更多選單：更改分類／移除
            PopupMenuButton<String>(
              tooltip: '更多',
              iconSize: 18,
              icon: Icon(Icons.more_vert, color: colors.text_muted),
              onSelected: (String action) {
                if (action == 'remove') {
                  controller.RemoveFromWatchlist(entry.symbol);
                } else if (action == 'group') {
                  _ShowChangeGroupDialog(context, entry);
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'group',
                  child: Text('更改分類'),
                ),
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('移除追蹤'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 市場標籤徽章：小字、subtle 底、圓角，低調不搶眼。
  Widget _BuildMarketBadge(String label, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.subtle_background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.text_secondary,
        ),
      ),
    );
  }

  /// 更改分類對話框：選既有分類或輸入新分類。
  Future<void> _ShowChangeGroupDialog(
      BuildContext context, WatchlistSymbol entry) async {
    final String? group = await WatchlistGroupPicker.Show(
        context, controller, entry.group_name);
    if (group != null && group != entry.group_name) {
      await controller.ChangeWatchlistGroup(entry.symbol, group);
    }
  }
}

/*
 * @class   WatchlistGroupPicker
 *
 * @brief   分類選擇器：列出既有分類＋新增分類輸入框（加入追蹤與更改分類共用）。
 */
class WatchlistGroupPicker extends StatefulWidget {
  final DashboardController controller;
  final String initial_group;

  const WatchlistGroupPicker({
    super.key,
    required this.controller,
    required this.initial_group,
  });

  /// 開啟選擇器；回傳選定的分類名稱（null = 取消）。
  static Future<String?> Show(BuildContext context,
      DashboardController controller, String initial_group) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => WatchlistGroupPicker(
        controller: controller,
        initial_group: initial_group,
      ),
    );
  }

  @override
  State<WatchlistGroupPicker> createState() => _WatchlistGroupPickerState();
}

class _WatchlistGroupPickerState extends State<WatchlistGroupPicker> {
  final TextEditingController new_group_controller = TextEditingController();
  late String selected_group = widget.initial_group;

  @override
  void dispose() {
    new_group_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> groups = <String>{
      '自選',
      ...widget.controller.GetWatchlistGroups(),
    }.toList();

    return AlertDialog(
      title: const Text('選擇分類',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String group in groups)
                  ChoiceChip(
                    label: Text(group, style: const TextStyle(fontSize: 12.5)),
                    selected: selected_group == group,
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() => selected_group = group);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: new_group_controller,
              decoration: const InputDecoration(
                labelText: '或輸入新分類',
                hintText: '例如：AI 概念股、ETF、觀察中',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (String value) {
                if (value.trim().isNotEmpty) {
                  setState(() => selected_group = value.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(selected_group),
          child: const Text('確定'),
        ),
      ],
    );
  }
}

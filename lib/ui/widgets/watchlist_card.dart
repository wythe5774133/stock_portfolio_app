// 自選股追蹤清單：分類 chips 過濾、現價與今日漲跌，
// 點列進入個股詳情頁，選單可更改分類或移除。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../database/app_database.dart' show WatchlistSymbol;
import '../../logic/market_registry.dart';
import '../../models/market_session.dart';
import '../../models/stock_quote.dart';
import '../dashboard_controller.dart';
import '../money_format.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';
import 'change_percent_badge.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   WatchlistCard
 *
 * @brief   追蹤清單：頂部分類 chips（全部＋各分類），每列為富途式三段——
 *          左段名稱/代號、中段迷你走勢圖、右段現價＋漲跌色塊（美股另附盤前/盤後），
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

  /// 單一追蹤列：左段名稱/代號、中段迷你走勢圖、右段現價＋漲跌色塊。
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
    final List<double> sparkline_closes =
        controller.GetSparklineCloses(entry.symbol);
    // 走勢圖線色以「當日漲跌方向」解析（無報價時退回中性色）
    final Color sparkline_color = change_percent != null
        ? change_color
        : colors.text_muted;
    final (String, double)? extended = _ResolveExtendedSessionChange(
        quote, market, controller.SessionForMarket(market.market_id));

    return InkWell(
      onTap: () => StockDetailPage.Open(
          context, controller, entry.symbol, entry.name),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 11, 8, 11),
        child: Row(
          children: <Widget>[
            // 左段：名稱（粗體）＋代號／台股 badge（弱化）
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(entry.symbol,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 11.5, color: colors.text_muted)),
                      ),
                      // 台股加低調市場標籤；美股不加，避免雜訊
                      if (market.market_id == 'tw') ...<Widget>[
                        const SizedBox(width: 6),
                        _BuildMarketBadge(market.market_label, colors),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 中段：迷你走勢圖（無快取時同尺寸空白佔位）
            _BuildSparkline(sparkline_closes, sparkline_color),
            const SizedBox(width: 8),
            // 右段：現價大字＋漲跌色塊＋（美股）盤前/盤後小字，右對齊堆疊
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  price_and_label.$1 != null
                      ? FormatMoney(price_and_label.$1!, market.currency)
                      : '—',
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                ChangePercentBadge(
                  percent: change_percent,
                  color: change_color,
                ),
                if (extended != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '${extended.$1} '
                    '${extended.$2 >= 0 ? '+' : ''}'
                    '${extended.$2.toStringAsFixed(2)}%',
                    style:
                        TextStyle(fontSize: 10.5, color: colors.text_muted),
                  ),
                ],
              ],
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

  /// 迷你走勢圖尺寸（富途式，寬 64 高 28）。
  static const double SPARKLINE_WIDTH = 64;
  static const double SPARKLINE_HEIGHT = 28;

  /*
   *  @fn      Widget _BuildSparkline(List<double> closes, Color color)
   *
   *  @brief   ( 用 fl_chart 極簡折線畫近 30 日收盤走勢，同色 10% 漸層填底 )
   *
   *  @param   closes - 由舊到新的收盤序列（少於兩點時視為無資料）
   *  @param   color - 線色（由呼叫端依當日漲跌方向解析）
   *
   *  @return  固定尺寸走勢圖；無足夠資料回傳同尺寸空白佔位
   *
   *  @note    無軸線、無格線、無觸控；資料一律取自 historical 快取，不發網路請求。
   */
  Widget _BuildSparkline(List<double> closes, Color color) {
    if (closes.length < 2) {
      return const SizedBox(
          width: SPARKLINE_WIDTH, height: SPARKLINE_HEIGHT);
    }

    double min_y = closes.first;
    double max_y = closes.first;
    for (final double value in closes) {
      if (value < min_y) {
        min_y = value;
      }
      if (value > max_y) {
        max_y = value;
      }
    }
    // 上下留白，避免折線貼齊邊界；全平序列給個最小範圍
    final double span = (max_y - min_y).abs();
    final double padding = span > 0 ? span * 0.15 : (max_y.abs() * 0.01 + 1);

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < closes.length; i++)
        FlSpot(i.toDouble(), closes[i]),
    ];

    return SizedBox(
      width: SPARKLINE_WIDTH,
      height: SPARKLINE_HEIGHT,
      child: LineChart(
        LineChartData(
          minY: min_y - padding,
          maxY: max_y + padding,
          minX: 0,
          maxX: (closes.length - 1).toDouble(),
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 1.6,
              isCurved: false,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
   *  @fn      (String, double)? _ResolveExtendedSessionChange(StockQuote? quote, MarketInfo market, MarketSession session)
   *
   *  @brief   ( 算美股盤前/盤後價相對盤中價的漲跌%，供右段第三行小字 )
   *
   *  @param   quote - 該檔最新報價
   *  @param   market - 市場資訊（台股永遠回 null）
   *  @param   session - 該檔市場目前時段
   *
   *  @return  (「盤前」|「盤後」, 相對盤中價的百分比)；不適用時回 null
   *
   *  @note    盤前取 pre_price、盤後/收盤取 post_price，皆相對 regular_price；
   *           缺盤中價或延長時段價時回 null。台股無盤前盤後，一律回 null。
   */
  (String, double)? _ResolveExtendedSessionChange(
      StockQuote? quote, MarketInfo market, MarketSession session) {
    if (quote == null ||
        market.market_id == 'tw' ||
        quote.regular_price == null ||
        quote.regular_price == 0) {
      return null;
    }
    final double regular = quote.regular_price!;
    if (session == MarketSession.premarket && quote.pre_price != null) {
      return ('盤前', (quote.pre_price! - regular) / regular * 100);
    }
    if ((session == MarketSession.postmarket ||
            session == MarketSession.closed) &&
        quote.post_price != null) {
      return ('盤後', (quote.post_price! - regular) / regular * 100);
    }
    return null;
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

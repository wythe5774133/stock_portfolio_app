// 個股詳情頁：即時報價標頭、日/週/月 K 線蠟燭圖、成交量、基本資訊與持倉摘要。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/market_registry.dart';
import '../models/holding_position.dart';
import '../models/market_session.dart';
import '../models/ohlcv_candle.dart';
import '../models/stock_news_item.dart';
import '../models/stock_quote.dart';
import 'dashboard_controller.dart';
import 'money_format.dart';
import 'theme/app_theme.dart';
import 'theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   StockDetailPage
 *
 * @brief   單一股票的詳情頁：現價與今日漲跌、K 線圖（日/週/月）、
 *          成交量柱狀圖、開高低收/52週/市值/本益比資訊格，
 *          若持有該股另顯示持倉摘要並在 K 線上畫出均價線。
 *
 * @note    K 線漲跌顏色跟隨使用者的配色慣例（美股/台股）。
 */
class StockDetailPage extends StatefulWidget {
  final DashboardController controller;
  final String symbol;
  final String display_name;

  const StockDetailPage({
    super.key,
    required this.controller,
    required this.symbol,
    required this.display_name,
  });

  /// 推入詳情頁。
  static void Open(
    BuildContext context,
    DashboardController controller,
    String symbol,
    String display_name,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StockDetailPage(
          controller: controller,
          symbol: symbol,
          display_name: display_name,
        ),
      ),
    );
  }

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  StockQuote? detail_quote; // 含 52 週/市值/本益比的完整報價
  CandleInterval selected_interval = CandleInterval.daily;
  CandleRange selected_range = GetDefaultRangeForInterval(CandleInterval.daily);
  final Map<String, List<OhlcvCandle>> candle_cache =
      <String, List<OhlcvCandle>>{};
  bool is_chart_loading = true;
  bool is_chart_unavailable = false;

  /// K 線與量能圖共用的縮放平移控制器（雙擊重置）
  final TransformationController chart_transform = TransformationController();

  List<StockNewsItem> news_items = <StockNewsItem>[];
  bool is_news_loading = true;

  @override
  void dispose() {
    chart_transform.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    LoadDetailQuote();
    LoadCandles(selected_interval, selected_range);
    LoadNews();
  }

  /// 抓取個股相關新聞。
  Future<void> LoadNews() async {
    final List<StockNewsItem> items = await widget.controller.repository
        .FetchNewsForSymbol(widget.symbol, display_name: widget.display_name);
    if (!mounted) {
      return;
    }
    setState(() {
      news_items = items;
      is_news_loading = false;
    });
  }

  /// 快取鍵：時間單位＋範圍。
  String _BuildCacheKey(CandleInterval interval, CandleRange range) {
    return '${interval.name}-${range.name}';
  }

  /// 抓取完整報價（52 週高低、市值、本益比等延伸欄位）。
  Future<void> LoadDetailQuote() async {
    final StockQuote? quote = await widget.controller.repository
        .FetchSingleQuote(widget.symbol);
    if (!mounted) {
      return;
    }
    setState(() => detail_quote = quote);
  }

  /// 抓取指定週期＋範圍的 K 線（頁內快取，切回不重抓）。
  Future<void> LoadCandles(CandleInterval interval, CandleRange range) async {
    final String cache_key = _BuildCacheKey(interval, range);
    if (candle_cache.containsKey(cache_key)) {
      setState(() {
        selected_interval = interval;
        selected_range = range;
        is_chart_unavailable = false;
      });
      return;
    }
    chart_transform.value = Matrix4.identity(); // 換資料時重置縮放
    setState(() {
      selected_interval = interval;
      selected_range = range;
      is_chart_loading = true;
      is_chart_unavailable = false;
    });
    final List<OhlcvCandle>? candles = await widget.controller.repository
        .FetchOhlcvCandles(widget.symbol, interval, range: range);
    if (!mounted) {
      return;
    }
    setState(() {
      is_chart_loading = false;
      if (candles == null || candles.isEmpty) {
        is_chart_unavailable = true;
      } else {
        candle_cache[cache_key] = candles;
      }
    });
  }

  /// 該股的持倉（未持有回傳 null）。
  HoldingPosition? FindHoldingPosition() {
    for (final HoldingPosition position in widget.controller.holdings) {
      if (position.symbol == widget.symbol && !position.is_closed) {
        return position;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final List<OhlcvCandle>? candles =
        candle_cache[_BuildCacheKey(selected_interval, selected_range)];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.page_background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '${widget.symbol}　${widget.display_name}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _BuildPriceHeader(colors),
                const SizedBox(height: 16),
                _BuildCard(
                  colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BuildIntervalSelector(),
                      const SizedBox(height: 12),
                      if (is_chart_loading)
                        const SizedBox(
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (is_chart_unavailable || candles == null)
                        const SizedBox(
                          height: 320,
                          child: Center(
                            child: Text(
                              'K 線資料暫時無法取得',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else ...<Widget>[
                        GestureDetector(
                          onDoubleTap: () =>
                              chart_transform.value = Matrix4.identity(),
                          child: Column(
                            children: <Widget>[
                              _BuildCandlestickChart(candles),
                              const SizedBox(height: 8),
                              _BuildVolumeChart(candles),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '捏合或滾輪縮放・拖曳平移・雙擊還原',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.text_muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _BuildCard(colors, child: _BuildQuoteInfoGrid(colors)),
                if (FindHoldingPosition() != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _BuildCard(colors, child: _BuildHoldingSummary(colors)),
                ],
                const SizedBox(height: 16),
                _BuildCard(colors, child: _BuildNewsSection(colors)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 價格標頭：現價、今日漲跌、時段標示。
  Widget _BuildPriceHeader(AppColors colors) {
    final Map<String, StockQuote> quotes =
        widget.controller.repository.quote_scheduler.latest_quotes;
    final StockQuote? quote = detail_quote ?? quotes[widget.symbol];
    final MarketInfo market = ResolveMarketForSymbol(widget.symbol);
    final (double?, String) price_and_label =
        DashboardController.ResolveDisplayPrice(
          quote,
          widget.controller.SessionForMarket(market.market_id),
          market,
        );
    final double? price = price_and_label.$1;

    double? change;
    double? change_percent;
    if (quote?.regular_price != null && quote?.previous_close != null) {
      change = quote!.regular_price! - quote.previous_close!;
      change_percent = change / quote.previous_close! * 100;
    }
    final Color change_color = change != null
        ? widget.controller.profit_colors.ResolveColorForValue(change)
        : colors.text_secondary;

    // Wrap 排版：窄螢幕（手機）時漲跌與時段自動換行，不會擠出畫面外
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: <Widget>[
        Text(
          price != null ? FormatMoney(price, market.currency) : '—',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colors.text_primary,
          ),
        ),
        if (change != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}　'
              '${change >= 0 ? '+' : ''}${change_percent!.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: change_color,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '${price_and_label.$2}價・'
            '${FormatMarketSession_Zh(widget.controller.SessionForMarket(market.market_id))}',
            style: TextStyle(fontSize: 12.5, color: colors.text_muted),
          ),
        ),
      ],
    );
  }

  /// 日K/週K/月K 與時間範圍切換。
  Widget _BuildIntervalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          children: <Widget>[
            for (final CandleInterval interval in CandleInterval.values)
              ChoiceChip(
                label: Text(
                  FormatCandleInterval(interval),
                  style: const TextStyle(fontSize: 12.5),
                ),
                selected: selected_interval == interval,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (bool selected) {
                  if (selected) {
                    LoadCandles(interval, GetDefaultRangeForInterval(interval));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: <Widget>[
            for (final CandleRange range in GetRangesForInterval(
              selected_interval,
            ))
              ChoiceChip(
                label: Text(
                  range.label,
                  style: const TextStyle(fontSize: 11.5),
                ),
                selected: selected_range == range,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (bool selected) {
                  if (selected) {
                    LoadCandles(selected_interval, range);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  /// K 線蠟燭圖（漲跌顏色跟隨使用者配色慣例，持有時畫均價虛線）。
  Widget _BuildCandlestickChart(List<OhlcvCandle> candles) {
    final ProfitColorScheme profit_colors = widget.controller.profit_colors;
    final HoldingPosition? position = FindHoldingPosition();

    double min_low = candles.first.low;
    double max_high = candles.first.high;
    for (final OhlcvCandle candle in candles) {
      if (candle.low < min_low) {
        min_low = candle.low;
      }
      if (candle.high > max_high) {
        max_high = candle.high;
      }
    }
    final double y_padding = (max_high - min_low) * 0.05 + 0.01;

    return SizedBox(
      height: 320,
      child: CandlestickChart(
        transformationConfig: FlTransformationConfig(
          scaleAxis: FlScaleAxis.horizontal,
          minScale: 1,
          maxScale: 20,
          trackpadScrollCausesScale: true,
          transformationController: chart_transform,
        ),
        CandlestickChartData(
          minY: min_low - y_padding,
          maxY: max_high + y_padding,
          candlestickSpots: <CandlestickSpot>[
            for (int i = 0; i < candles.length; i++)
              CandlestickSpot(
                x: i.toDouble(),
                open: candles[i].open,
                high: candles[i].high,
                low: candles[i].low,
                close: candles[i].close,
              ),
          ],
          candlestickPainter: DefaultCandlestickPainter(
            candlestickStyleProvider: (CandlestickSpot spot, int index) {
              final Color color = spot.close >= spot.open
                  ? profit_colors.gain_color
                  : profit_colors.loss_color;
              return CandlestickStyle(
                lineColor: color,
                lineWidth: 1.2,
                bodyStrokeColor: color,
                bodyStrokeWidth: 0,
                bodyFillColor: color,
                bodyWidth: 6,
                bodyRadius: 1,
              );
            },
          ),
          // 持有時以半透明水平帶標出加權平均成本
          rangeAnnotations: position != null
              ? RangeAnnotations(
                  horizontalRangeAnnotations: <HorizontalRangeAnnotation>[
                    HorizontalRangeAnnotation(
                      y1: position.average_cost - y_padding * 0.06,
                      y2: position.average_cost + y_padding * 0.06,
                      color: const Color(0xFF4F6DF5).withValues(alpha: 0.85),
                    ),
                  ],
                )
              : const RangeAnnotations(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      value.toStringAsFixed(value >= 1000 ? 0 : 1),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: (candles.length / 5).ceilToDouble(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= candles.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      FormatCandleDateLabel(
                        candles[index].date,
                        selected_interval,
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          candlestickTouchData: CandlestickTouchData(
            touchTooltipData: CandlestickTouchTooltipData(
              maxContentWidth: 200,
              getTooltipColor: (CandlestickSpot spot) =>
                  Colors.black.withValues(alpha: 0.8),
              getTooltipItems:
                  (
                    FlCandlestickPainter painter,
                    CandlestickSpot spot,
                    int index,
                  ) {
                    final OhlcvCandle candle = candles[index];
                    return CandlestickTooltipItem(
                      '${FormatFullDate(candle.date)}\n'
                      '開 ${candle.open.toStringAsFixed(2)}  '
                      '高 ${candle.high.toStringAsFixed(2)}\n'
                      '低 ${candle.low.toStringAsFixed(2)}  '
                      '收 ${candle.close.toStringAsFixed(2)}\n'
                      '量 ${FormatCompactNumber(candle.volume)}',
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.left,
                    );
                  },
            ),
          ),
        ),
      ),
    );
  }

  /// 成交量柱狀圖（顏色跟隨該根 K 線漲跌）。
  Widget _BuildVolumeChart(List<OhlcvCandle> candles) {
    final ProfitColorScheme profit_colors = widget.controller.profit_colors;
    final double max_volume = candles
        .map((OhlcvCandle c) => c.volume)
        .reduce((double a, double b) => a > b ? a : b);

    return SizedBox(
      height: 80,
      child: BarChart(
        transformationConfig: FlTransformationConfig(
          scaleAxis: FlScaleAxis.horizontal,
          minScale: 1,
          maxScale: 20,
          trackpadScrollCausesScale: true,
          transformationController: chart_transform,
        ),
        BarChartData(
          maxY: max_volume * 1.05,
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < candles.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: candles[i].volume,
                    width: 3,
                    color:
                        (candles[i].is_bullish
                                ? profit_colors.gain_color
                                : profit_colors.loss_color)
                            .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.zero,
                  ),
                ],
              ),
          ],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                interval: max_volume / 2,
                getTitlesWidget: (double value, TitleMeta meta) {
                  // 0 與貼近頂端的刻度不畫，避免與相鄰標籤重疊
                  if (value == 0 || value > max_volume * 0.85) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      FormatCompactNumber(value),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 基本資訊格：開高低收、52 週、市值、本益比。
  Widget _BuildQuoteInfoGrid(AppColors colors) {
    final StockQuote? quote = detail_quote;
    final String currency = ResolveMarketForSymbol(widget.symbol).currency;
    final List<(String, String)> items = <(String, String)>[
      ('今開', FormatPrice(quote?.open_price, currency)),
      ('今高', FormatPrice(quote?.day_high, currency)),
      ('今低', FormatPrice(quote?.day_low, currency)),
      ('昨收', FormatPrice(quote?.previous_close, currency)),
      (
        '成交量',
        quote?.volume != null ? FormatCompactNumber(quote!.volume!) : '—',
      ),
      ('52週高', FormatPrice(quote?.fifty_two_week_high, currency)),
      ('52週低', FormatPrice(quote?.fifty_two_week_low, currency)),
      (
        '市值',
        quote?.market_cap != null
            ? FormatCompactNumber(quote!.market_cap!)
            : '—',
      ),
      (
        '本益比',
        quote?.trailing_pe != null
            ? quote!.trailing_pe!.toStringAsFixed(2)
            : '—',
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 14,
      children: <Widget>[
        for (final (String, String) item in items)
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.$1,
                  style: TextStyle(fontSize: 12, color: colors.text_secondary),
                ),
                const SizedBox(height: 3),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text_primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 持倉摘要（僅持有時顯示）。
  Widget _BuildHoldingSummary(AppColors colors) {
    final HoldingPosition position = FindHoldingPosition()!;
    final HoldingDisplayRow? display_row = widget.controller
        .BuildHoldingDisplayRows()
        .where((HoldingDisplayRow r) => r.position.symbol == widget.symbol)
        .firstOrNull;
    final String currency = ResolveMarketForSymbol(widget.symbol).currency;
    final Color pnl_color = widget.controller.profit_colors
        .ResolveColorForValue(display_row?.unrealized_pnl ?? 0);

    final List<(String, String, Color?)> items = <(String, String, Color?)>[
      ('持股', position.net_quantity.toStringAsFixed(5), null),
      ('平均成本', FormatMoney(position.average_cost, currency), null),
      (
        '市值',
        display_row != null
            ? FormatMoney(display_row.market_value, currency)
            : '—',
        null,
      ),
      (
        '未實現損益',
        display_row != null
            ? '${display_row.unrealized_pnl >= 0 ? '+' : ''}'
                  '${FormatMoney(display_row.unrealized_pnl, currency)}'
                  '（${display_row.unrealized_pnl >= 0 ? '+' : ''}'
                  '${display_row.unrealized_pnl_percent.toStringAsFixed(2)}%）'
            : '—',
        pnl_color,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '我的持倉',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.text_primary,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 18, height: 3, color: const Color(0xFF4F6DF5)),
            const SizedBox(width: 4),
            Text(
              'K 線上的藍線為你的平均成本',
              style: TextStyle(fontSize: 11.5, color: colors.text_muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 14,
          children: <Widget>[
            for (final (String, String, Color?) item in items)
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.text_secondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: item.$3 ?? colors.text_primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 相關新聞區塊：標題、來源與相對時間，點擊以瀏覽器開啟原文。
  Widget _BuildNewsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '相關新聞',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.text_primary,
          ),
        ),
        const SizedBox(height: 6),
        if (is_news_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (news_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '目前沒有相關新聞',
              style: TextStyle(fontSize: 12.5, color: colors.text_muted),
            ),
          )
        else
          for (int i = 0; i < news_items.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: colors.divider),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(news_items[i].link),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      news_items[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.text_primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      news_items[i].published_at != null
                          ? '${news_items[i].publisher}・'
                                '${FormatNewsTime(news_items[i].published_at!)}'
                          : news_items[i].publisher,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.text_muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }

  /// 新聞相對時間（X 分鐘前／X 小時前／日期）。
  static String FormatNewsTime(DateTime time) {
    final Duration elapsed = DateTime.now().difference(time);
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} 分鐘前';
    }
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours} 小時前';
    }
    if (elapsed.inDays < 7) {
      return '${elapsed.inDays} 天前';
    }
    return DateFormat('yyyy/MM/dd').format(time);
  }

  /// 通用卡片容器。
  Widget _BuildCard(AppColors colors, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: child,
    );
  }

  /// 價格欄位格式化（null 顯示 —；依幣別加符號，台股為 NT$）。
  static String FormatPrice(double? value, String currency) {
    return value != null ? FormatMoney(value, currency) : '—';
  }

  /// 大數字縮寫（1.23M、45.6B）。
  static String FormatCompactNumber(double value) {
    return NumberFormat.compact().format(value);
  }

  /// K 線 X 軸日期標籤（日K：M/d，週K：yy/M/d，月K：yy/M）。
  static String FormatCandleDateLabel(int yyyymmdd, CandleInterval interval) {
    final int year = yyyymmdd ~/ 10000;
    final int month = (yyyymmdd ~/ 100) % 100;
    final int day = yyyymmdd % 100;
    switch (interval) {
      case CandleInterval.daily:
        return '$month/$day';
      case CandleInterval.weekly:
        return '${year % 100}/$month/$day';
      case CandleInterval.monthly:
        return '${year % 100}/$month';
    }
  }

  /// 完整日期 yyyy/MM/dd。
  static String FormatFullDate(int yyyymmdd) {
    return '${yyyymmdd ~/ 10000}/${(yyyymmdd ~/ 100) % 100}/${yyyymmdd % 100}';
  }

  /// 時段中文名稱。
  static String FormatMarketSession_Zh(MarketSession session) {
    switch (session) {
      case MarketSession.premarket:
        return '盤前';
      case MarketSession.regular:
        return '盤中';
      case MarketSession.postmarket:
        return '盤後';
      case MarketSession.closed:
        return '休市';
    }
  }
}

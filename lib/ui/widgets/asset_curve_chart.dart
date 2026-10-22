// 資產曲線圖：總市值與總成本兩條折線，X 軸為日期，Y 軸依期間資料自動縮放。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/portfolio_snapshot.dart';
import '../money_format.dart';
import 'chart_axis_helper.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AssetCurveChart
 *
 * @brief   以歷史每日快照繪製市值/成本雙折線圖，含互動 tooltip 與圖例。
 */
class AssetCurveChart extends StatelessWidget {
  static const Color MARKET_VALUE_COLOR = Color(0xFF4F6DF5);
  static const Color COST_COLOR = Color(0xFF9CA3AF);
  static const double LEFT_TITLE_WIDTH = 64; // 左側 Y 軸標籤保留寬度

  final List<PortfolioSnapshot> history;
  final String currency; // 序列已換算後的顯示幣別，供金額格式化

  const AssetCurveChart({
    super.key,
    required this.history,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: Text('尚無足夠的歷史資料', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final List<FlSpot> market_value_spots = <FlSpot>[];
    final List<FlSpot> cost_spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      market_value_spots
          .add(FlSpot(i.toDouble(), history[i].total_market_value));
      cost_spots.add(FlSpot(i.toDouble(), history[i].total_cost_basis));
    }

    double data_min = double.infinity;
    double data_max = double.negativeInfinity;
    for (final PortfolioSnapshot snapshot in history) {
      for (final double value in <double>[
        snapshot.total_market_value,
        snapshot.total_cost_basis,
      ]) {
        if (value < data_min) {
          data_min = value;
        }
        if (value > data_max) {
          data_max = value;
        }
      }
    }
    final NiceAxisRange y_range = CalculateNiceAxisRange(data_min, data_max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _BuildLegendDot(MARKET_VALUE_COLOR, '總市值'),
            const SizedBox(width: 16),
            _BuildLegendDot(COST_COLOR, '總成本'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minY: y_range.min,
              maxY: y_range.max,
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: market_value_spots,
                  color: MARKET_VALUE_COLOR,
                  barWidth: 2.4,
                  isCurved: false,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: MARKET_VALUE_COLOR.withValues(alpha: 0.08),
                  ),
                ),
                LineChartBarData(
                  spots: cost_spots,
                  color: COST_COLOR,
                  barWidth: 1.8,
                  isCurved: false,
                  dashArray: <int>[6, 4],
                  dotData: const FlDotData(show: false),
                ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: y_range.interval,
                getDrawingHorizontalLine: (double value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: LEFT_TITLE_WIDTH,
                    interval: y_range.interval,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(
                          FormatAxisMoney(value, y_range, currency),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (LineBarSpot spot) =>
                      Colors.black.withValues(alpha: 0.78),
                  getTooltipItems: (List<LineBarSpot> spots) {
                    return spots.map((LineBarSpot spot) {
                      final String series_name =
                          spot.barIndex == 0 ? '市值' : '成本';
                      final String date_label =
                          FormatDateLabel(history[spot.x.toInt()].date);
                      return LineTooltipItem(
                        '$date_label $series_name\n'
                        '${FormatMoney(spot.y, currency)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        DateAxisLabelRow(
          dates: <int>[for (final PortfolioSnapshot s in history) s.date],
          left_reserved: LEFT_TITLE_WIDTH,
        ),
      ],
    );
  }

  /// 圖例圓點 + 文字。
  Widget _BuildLegendDot(Color color, String label) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  /// yyyyMMdd 整數轉「M/d」或跨年時「yy/M/d」標籤。
  static String FormatDateLabel(int yyyymmdd) {
    final int year = yyyymmdd ~/ 10000;
    final int month = (yyyymmdd ~/ 100) % 100;
    final int day = yyyymmdd % 100;
    final int current_year = DateTime.now().year;
    return year == current_year ? '$month/$day' : '${year % 100}/$month/$day';
  }
}

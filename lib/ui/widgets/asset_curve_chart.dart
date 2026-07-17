// 資產曲線圖：總市值與總成本兩條折線，X 軸為日期。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/portfolio_snapshot.dart';
import '../money_format.dart';

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

    final double max_y = history
        .map((PortfolioSnapshot s) => s.total_market_value > s.total_cost_basis
            ? s.total_market_value
            : s.total_cost_basis)
        .reduce((double a, double b) => a > b ? a : b);

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
              minY: 0,
              maxY: max_y * 1.08,
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
                    reservedSize: 56,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        FormatMoney(value, currency, compact: true),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (history.length / 4).ceilToDouble(),
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= history.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          FormatDateLabel(history[index].date),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
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

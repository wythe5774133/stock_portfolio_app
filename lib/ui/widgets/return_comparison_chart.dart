// 報酬率比較圖：組合與大盤指數的累計報酬率 %，起點歸零。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 一條報酬率曲線的資料。
class ReturnSeriesEntry {
  final String label; // 圖例名稱（我的組合 / S&P 500 ...）
  final Color color;
  final List<double?> percents; // 與 dates 等長，尚無資料的日期為 null

  const ReturnSeriesEntry({
    required this.label,
    required this.color,
    required this.percents,
  });
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   ReturnComparisonChart
 *
 * @brief   多條累計報酬率 % 折線圖（比較模式），Y 軸為 %，含 0% 基準線。
 */
class ReturnComparisonChart extends StatelessWidget {
  final List<int> dates; // yyyyMMdd 序列
  final List<ReturnSeriesEntry> series;

  const ReturnComparisonChart({
    super.key,
    required this.dates,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    if (dates.length < 2 || series.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: Text('尚無足夠的歷史資料', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    double min_percent = 0;
    double max_percent = 0;
    for (final ReturnSeriesEntry entry in series) {
      for (final double? value in entry.percents) {
        if (value == null) {
          continue;
        }
        if (value < min_percent) {
          min_percent = value;
        }
        if (value > max_percent) {
          max_percent = value;
        }
      }
    }
    final double padding = ((max_percent - min_percent).abs()) * 0.08 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: <Widget>[
            for (final ReturnSeriesEntry entry in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: entry.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(entry.label,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minY: min_percent - padding,
              maxY: max_percent + padding,
              lineBarsData: <LineChartBarData>[
                for (final ReturnSeriesEntry entry in series)
                  LineChartBarData(
                    spots: <FlSpot>[
                      for (int i = 0; i < entry.percents.length; i++)
                        if (entry.percents[i] != null)
                          FlSpot(i.toDouble(), entry.percents[i]!),
                    ],
                    color: entry.color,
                    barWidth: 2.2,
                    isCurved: false,
                    dotData: const FlDotData(show: false),
                  ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (double value) => FlLine(
                  color: value.abs() < 0.001
                      ? Colors.grey.withValues(alpha: 0.5) // 0% 基準線加深
                      : Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: value.abs() < 0.001 ? 1.4 : 1,
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
                    reservedSize: 52,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value == meta.max || value == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toStringAsFixed(0)}%',
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
                    interval: (dates.length / 4).ceilToDouble(),
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          FormatDateLabel(dates[index]),
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
                      final ReturnSeriesEntry entry = series[spot.barIndex];
                      return LineTooltipItem(
                        '${entry.label} '
                        '${spot.y >= 0 ? '+' : ''}${spot.y.toStringAsFixed(2)}%',
                        TextStyle(
                            color: entry.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
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

  /// yyyyMMdd 整數轉「M/d」或跨年時「yy/M/d」標籤。
  static String FormatDateLabel(int yyyymmdd) {
    final int year = yyyymmdd ~/ 10000;
    final int month = (yyyymmdd ~/ 100) % 100;
    final int day = yyyymmdd % 100;
    final int current_year = DateTime.now().year;
    return year == current_year ? '$month/$day' : '${year % 100}/$month/$day';
  }
}

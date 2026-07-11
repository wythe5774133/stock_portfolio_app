// 持倉圓餅圖：通用元件，市值配置與成本配置共用（傳入不同數值來源）。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 圓餅圖單一切片的資料。
class PieSliceEntry {
  final String label;
  final double value;

  const PieSliceEntry({required this.label, required this.value});
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HoldingPieChart
 *
 * @brief   甜甜圈圓餅圖 + 右側圖例（代號、金額、占比）。
 *
 * @note    切片顏色依固定調色盤循環；占比小於 4% 的切片不顯示內嵌標籤，
 *          避免文字重疊。
 */
class HoldingPieChart extends StatelessWidget {
  static const List<Color> SLICE_PALETTE = <Color>[
    Color(0xFF4F6DF5), // 藍
    Color(0xFF22C55E), // 綠
    Color(0xFFF59E0B), // 琥珀
    Color(0xFFEC4899), // 粉
    Color(0xFF8B5CF6), // 紫
    Color(0xFF14B8A6), // 藍綠
    Color(0xFFF97316), // 橘
    Color(0xFF64748B), // 石板灰
  ];

  final List<PieSliceEntry> entries;

  const HoldingPieChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final List<PieSliceEntry> positive_entries =
        entries.where((PieSliceEntry e) => e.value > 0).toList()
          ..sort((PieSliceEntry a, PieSliceEntry b) =>
              b.value.compareTo(a.value));
    if (positive_entries.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text('尚無資料', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final double total = positive_entries.fold(
        0.0, (double sum, PieSliceEntry e) => sum + e.value);

    return SizedBox(
      height: 220,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                sections: <PieChartSectionData>[
                  for (int i = 0; i < positive_entries.length; i++)
                    PieChartSectionData(
                      value: positive_entries[i].value,
                      color: SLICE_PALETTE[i % SLICE_PALETTE.length],
                      radius: 52,
                      showTitle:
                          positive_entries[i].value / total >= 0.04,
                      title:
                          '${(positive_entries[i].value / total * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < positive_entries.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: SLICE_PALETTE[i % SLICE_PALETTE.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              positive_entries[i].label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            NumberFormat.compactCurrency(symbol: r'$')
                                .format(positive_entries[i].value),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

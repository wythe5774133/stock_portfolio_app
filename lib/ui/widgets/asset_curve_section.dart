// 資產曲線區塊：時間範圍選擇、大盤指數比較勾選、期間損益顯示與圖表切換。
// 未勾選任何指數 → 金額模式（市值＋成本）；勾選後 → 報酬率 % 比較模式。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../logic/portfolio_repository.dart';
import '../../models/portfolio_snapshot.dart';
import '../dashboard_controller.dart';
import 'asset_curve_chart.dart';
import 'return_comparison_chart.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AssetCurveSection
 *
 * @brief   資產曲線卡片內容：範圍膠囊列（1月～全部）、期間損益（金額＋%）、
 *          大盤比較 FilterChip（S&P 500 / 那斯達克 / 台灣加權）與對應圖表。
 */
class AssetCurveSection extends StatelessWidget {
  /// 各指數在比較圖中的固定顏色。
  static const Map<String, Color> BENCHMARK_COLORS = <String, Color>{
    '^GSPC': Color(0xFFF59E0B), // S&P 500 琥珀
    '^IXIC': Color(0xFF8B5CF6), // 那斯達克 紫
    '^TWII': Color(0xFFEC4899), // 台灣加權 粉
  };
  static const Color PORTFOLIO_COLOR = Color(0xFF4F6DF5);

  final DashboardController controller;

  const AssetCurveSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final List<PortfolioSnapshot> visible = controller.GetVisibleHistory();
    final bool comparison_mode = controller.selected_benchmarks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BuildRangeSelectorRow(),
        const SizedBox(height: 10),
        _BuildPeriodPnlRow(),
        const SizedBox(height: 14),
        if (comparison_mode)
          _BuildComparisonChart(visible)
        else
          AssetCurveChart(history: visible),
        const SizedBox(height: 12),
        _BuildBenchmarkChipRow(),
      ],
    );
  }

  /// 時間範圍膠囊列。
  Widget _BuildRangeSelectorRow() {
    return Wrap(
      spacing: 6,
      children: <Widget>[
        for (final CurveRange range in CurveRange.values)
          ChoiceChip(
            label: Text(FormatCurveRange(range),
                style: const TextStyle(fontSize: 12.5)),
            selected: controller.curve_range == range,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (bool selected) {
              if (selected) {
                controller.SwitchCurveRange(range);
              }
            },
          ),
      ],
    );
  }

  /// 期間損益列（金額＋報酬率%，顏色依配色慣例）。
  Widget _BuildPeriodPnlRow() {
    final double pnl = controller.period_pnl;
    final double percent = controller.period_return_percent;
    final Color color = controller.profit_colors.ResolveColorForValue(pnl);
    final String sign = pnl >= 0 ? '+' : '';
    final NumberFormat money = NumberFormat.currency(symbol: r'$');

    // Wrap：手機窄度時 % 徽章與說明圖示自動換行，不會溢出
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          '期間損益　$sign${money.format(pnl)}',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: color),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$sign${percent.toStringAsFixed(2)}%',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const Tooltip(
          message: '期間損益 = 期末市值 − 期初市值 − 期間淨投入本金\n'
              '報酬率採時間加權法（TWR），新投入的本金不會被算成獲利',
          child: Icon(Icons.info_outline, size: 15, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  /// 比較模式的報酬率圖。
  Widget _BuildComparisonChart(List<PortfolioSnapshot> visible) {
    final List<int> dates =
        visible.map((PortfolioSnapshot s) => s.date).toList();
    final List<double> portfolio_percents =
        controller.BuildPortfolioReturnPercentSeries();

    final List<ReturnSeriesEntry> series = <ReturnSeriesEntry>[
      ReturnSeriesEntry(
        label: '我的組合',
        color: PORTFOLIO_COLOR,
        percents: portfolio_percents,
      ),
      for (final MapEntry<String, String> benchmark
          in PortfolioRepository.BENCHMARK_INDEXES.entries)
        if (controller.selected_benchmarks.contains(benchmark.value))
          ReturnSeriesEntry(
            label: benchmark.key,
            color: BENCHMARK_COLORS[benchmark.value] ?? Colors.grey,
            percents:
                controller.BuildBenchmarkReturnPercentSeries(benchmark.value),
          ),
    ];

    return ReturnComparisonChart(dates: dates, series: series);
  }

  /// 大盤指數比較勾選列。
  Widget _BuildBenchmarkChipRow() {
    return Row(
      children: <Widget>[
        const Text('比較大盤：',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: <Widget>[
              for (final MapEntry<String, String> benchmark
                  in PortfolioRepository.BENCHMARK_INDEXES.entries)
                FilterChip(
                  label: Text(benchmark.key,
                      style: const TextStyle(fontSize: 12)),
                  selected:
                      controller.selected_benchmarks.contains(benchmark.value),
                  checkmarkColor:
                      BENCHMARK_COLORS[benchmark.value] ?? Colors.grey,
                  visualDensity: VisualDensity.compact,
                  onSelected: (bool selected) {
                    controller.ToggleBenchmark(benchmark.value);
                  },
                ),
            ],
          ),
        ),
        if (controller.is_benchmark_loading)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

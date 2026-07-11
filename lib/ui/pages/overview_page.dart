// 總覽分頁：時段狀態、統計卡片、資產曲線與雙圓餅圖。

import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../widgets/asset_curve_section.dart';
import '../widgets/holding_pie_chart.dart';
import '../widgets/quote_status_banner.dart';
import '../widgets/section_card.dart';
import '../widgets/summary_stat_cards.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   OverviewPage
 *
 * @brief   總覽分頁：整體資產狀況一眼看完（統計卡片、資產曲線、配置圓餅）。
 */
class OverviewPage extends StatelessWidget {
  final DashboardController controller;

  const OverviewPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final List<HoldingDisplayRow> rows = controller.BuildHoldingDisplayRows();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              QuoteStatusBanner(
                session: controller.current_session,
                last_updated_at: controller.last_updated_at,
                is_quote_unavailable: controller.is_quote_unavailable,
              ),
              const SizedBox(height: 14),
              SummaryStatCards(
                total_market_value: controller.total_market_value,
                total_cost_basis: controller.total_cost_basis,
                total_unrealized_pnl: controller.total_unrealized_pnl,
                total_unrealized_pnl_percent:
                    controller.total_unrealized_pnl_percent,
                total_realized_pnl: controller.total_realized_pnl,
                total_day_pnl: controller.total_day_pnl,
                total_day_change_percent: controller.total_day_change_percent,
                total_dividend_income: controller.total_dividend_income,
                portfolio_xirr: controller.portfolio_xirr,
                show_dividend_card: controller.dividend_tracking_enabled,
                profit_colors: controller.profit_colors,
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '資產曲線',
                trailing: controller.is_history_loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                child: AssetCurveSection(controller: controller),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget market_value_pie = SectionCard(
                    title: '持倉配置（依市值）',
                    child: HoldingPieChart(
                      entries: rows
                          .map((HoldingDisplayRow r) => PieSliceEntry(
                              label: r.position.symbol,
                              value: r.market_value))
                          .toList(),
                    ),
                  );
                  final Widget cost_pie = SectionCard(
                    title: '成本配置（依投入成本）',
                    child: HoldingPieChart(
                      entries: rows
                          .map((HoldingDisplayRow r) => PieSliceEntry(
                              label: r.position.symbol,
                              value: r.position.total_cost_basis))
                          .toList(),
                    ),
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(children: <Widget>[
                      market_value_pie,
                      const SizedBox(height: 14),
                      cost_pie,
                    ]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: market_value_pie),
                      const SizedBox(width: 14),
                      Expanded(child: cost_pie),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// 總覽分頁：時段狀態、統計卡片、資產曲線與雙圓餅圖。

import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_curve_section.dart';
import '../widgets/holding_pie_chart.dart';
import '../widgets/quote_status_banner.dart';
import '../widgets/portfolio_risk_card.dart';
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
    final String display_currency = controller.display_currency_effective;

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
              _BuildCurrencySwitcher(context),
              const SizedBox(height: 12),
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
                display_currency: display_currency,
                profit_colors: controller.profit_colors,
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '資產曲線',
                trailing: controller.is_history_loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                child: AssetCurveSection(controller: controller),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '風險概覽',
                subtitle: '依目前選擇的資產曲線期間計算',
                child: PortfolioRiskCard(
                  metrics: controller.portfolio_risk_metrics,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget market_value_pie = SectionCard(
                    title: '持倉配置（依市值）',
                    child: HoldingPieChart(
                      currency: display_currency,
                      entries: rows
                          .map(
                            (HoldingDisplayRow r) => PieSliceEntry(
                              label: r.position.symbol,
                              // 換算成顯示幣別，混幣別佔比才正確
                              value: controller.ConvertToDisplayCurrency(
                                r.market_value,
                                r.market.currency,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                  final Widget cost_pie = SectionCard(
                    title: '成本配置（依投入成本）',
                    child: HoldingPieChart(
                      currency: display_currency,
                      entries: rows
                          .map(
                            (HoldingDisplayRow r) => PieSliceEntry(
                              label: r.position.symbol,
                              value: controller.ConvertToDisplayCurrency(
                                r.position.total_cost_basis,
                                r.market.currency,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(
                      children: <Widget>[
                        market_value_pie,
                        const SizedBox(height: 14),
                        cost_pie,
                      ],
                    );
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

  /*
   *  @fn      Widget _BuildCurrencySwitcher(BuildContext context)
   *
   *  @brief   ( 顯示幣別切換：USD｜TWD 分段鈕，附匯率或取得中提示 )
   *
   *  @param   context - 建構脈絡（取色用）
   *
   *  @return  幣別切換列（Wrap 排版，手機桌面皆不跑版）
   *
   *  @note    想顯示 TWD 但無匯率時，金額仍以美元呈現（display_currency_effective
   *           已處理），此處附上「匯率取得中」小字說明。
   */
  Widget _BuildCurrencySwitcher(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final double? rate = controller.usd_twd_rate;
    final bool wants_twd =
        controller.display_currency == DashboardController.CURRENCY_TWD;

    // 想看台幣但匯率還沒到：提示暫以美元顯示
    Widget? hint;
    if (wants_twd && rate == null) {
      hint = Text(
        '匯率取得中，暫以美元顯示',
        style: TextStyle(fontSize: 12, color: colors.text_muted),
      );
    } else if (wants_twd && rate != null) {
      // 顯示台幣且已有匯率：標示目前匯率讓數字可信
      hint = Text(
        '1 USD = ${rate.toStringAsFixed(2)} TWD',
        style: TextStyle(fontSize: 12, color: colors.text_muted),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: DashboardController.CURRENCY_USD,
              label: Text('USD'),
            ),
            ButtonSegment<String>(
              value: DashboardController.CURRENCY_TWD,
              label: Text('TWD'),
            ),
          ],
          selected: <String>{controller.display_currency},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll<TextStyle>(
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          onSelectionChanged: (Set<String> selection) {
            controller.SwitchDisplayCurrency(selection.first);
          },
        ),
        ?hint,
      ],
    );
  }
}

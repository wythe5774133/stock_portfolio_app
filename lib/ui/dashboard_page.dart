// 儀表板主頁：統計卡片、資產曲線、雙圓餅圖、持倉列表與工具列。

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/holding_position.dart';
import '../services/csv_transaction_importer.dart';
import 'dashboard_controller.dart';
import 'theme/app_theme.dart';
import 'theme/profit_color_scheme.dart';
import 'widgets/add_transaction_dialog.dart';
import 'widgets/add_watchlist_dialog.dart';
import 'widgets/asset_curve_section.dart';
import 'widgets/holding_list_view.dart';
import 'widgets/holding_pie_chart.dart';
import 'widgets/quote_status_banner.dart';
import 'widgets/summary_stat_cards.dart';
import 'widgets/watchlist_card.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   DashboardPage
 *
 * @brief   首頁儀表板：同時呈現總資產/總成本/總損益、資產曲線、
 *          市值與成本雙圓餅圖、可展開的個股列表。
 */
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller =
        context.watch<DashboardController>();

    return Scaffold(
      body: controller.is_loading
          ? const Center(child: CircularProgressIndicator())
          : _BuildDashboardBody(context, controller),
    );
  }

  /// 儀表板主體（含頂部工具列）。
  Widget _BuildDashboardBody(
      BuildContext context, DashboardController controller) {
    final List<HoldingDisplayRow> rows = controller.BuildHoldingDisplayRows();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BuildTopBar(context, controller),
              const SizedBox(height: 8),
              QuoteStatusBanner(
                session: controller.current_session,
                last_updated_at: controller.last_updated_at,
                is_quote_unavailable: controller.is_quote_unavailable,
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 16),
              _BuildSectionCard(
                context: context,
                title: '資產曲線',
                trailing: controller.is_history_loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                child: AssetCurveSection(controller: controller),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget market_value_pie = _BuildSectionCard(
                    context: context,
                    title: '持倉配置（依市值）',
                    child: HoldingPieChart(
                      entries: rows
                          .map((HoldingDisplayRow r) => PieSliceEntry(
                              label: r.position.symbol,
                              value: r.market_value))
                          .toList(),
                    ),
                  );
                  final Widget cost_pie = _BuildSectionCard(
                    context: context,
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
                      const SizedBox(height: 16),
                      cost_pie,
                    ]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: market_value_pie),
                      const SizedBox(width: 16),
                      Expanded(child: cost_pie),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _BuildSectionCard(
                context: context,
                title: '持倉明細',
                subtitle: '成本採${controller.cost_method_name}計算，點擊列展開交易明細',
                padding: EdgeInsets.zero,
                title_padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: HoldingListView(
                  rows: rows,
                  profit_colors: controller.profit_colors,
                  controller: controller,
                ),
              ),
              const SizedBox(height: 16),
              _BuildSectionCard(
                context: context,
                title: '追蹤清單',
                subtitle: '不需持有也能關注，點列查看 K 線與詳情',
                padding: EdgeInsets.zero,
                title_padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                trailing: TextButton.icon(
                  onPressed: () => AddWatchlistDialog.Show(context, controller),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('追蹤', style: TextStyle(fontSize: 13)),
                ),
                child: WatchlistCard(controller: controller),
              ),
              if (controller.GetClosedPositions().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _BuildClosedPositionsCard(context, controller),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 頂部工具列：標題 + 更新 / 主題 / 配色 / 匯入 / 記帳按鈕。
  Widget _BuildTopBar(BuildContext context, DashboardController controller) {
    final AppColors colors = AppColors.Of(context);
    return Row(
      children: <Widget>[
        const Text(
          '股票庫存',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '立即更新報價',
          onPressed: () => controller.RefreshQuotesNow(),
          icon: const Icon(Icons.refresh, size: 21),
        ),
        _BuildSettingsMenu(controller),
        _BuildThemeModeMenu(context, controller),
        _BuildColorConventionMenu(controller),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _PickAndImportCsvFile(context, controller),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('匯入 CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.text_primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _OpenAddTransactionDialog(context, controller),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('記一筆'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary_button_background,
            foregroundColor: colors.primary_button_foreground,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// 一般設定選單（目前含股息追蹤開關）。
  Widget _BuildSettingsMenu(DashboardController controller) {
    return PopupMenuButton<String>(
      tooltip: '設定',
      icon: const Icon(Icons.settings_outlined, size: 21),
      onSelected: (String key) {
        if (key == 'dividend_tracking') {
          controller
              .SwitchDividendTracking(!controller.dividend_tracking_enabled);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        CheckedPopupMenuItem<String>(
          value: 'dividend_tracking',
          checked: controller.dividend_tracking_enabled,
          child: const Text('股息追蹤'),
        ),
        const PopupMenuItem<String>(
          enabled: false,
          height: 40,
          child: Text(
            '券商有開股息再投資（DRIP）時請保持關閉，\n避免股息被重複計算',
            style: TextStyle(fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  /// 深淺主題切換選單。
  Widget _BuildThemeModeMenu(
      BuildContext context, DashboardController controller) {
    return PopupMenuButton<AppThemeMode>(
      tooltip: '背景深淺',
      icon: Icon(
        controller.theme_mode == AppThemeMode.dark ||
                (controller.theme_mode == AppThemeMode.system &&
                    Theme.of(context).brightness == Brightness.dark)
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        size: 21,
      ),
      initialValue: controller.theme_mode,
      onSelected: controller.SwitchAppThemeMode,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<AppThemeMode>>[
        const PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.light,
          child: Text('淺色背景'),
        ),
        const PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.dark,
          child: Text('深色背景'),
        ),
        const PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.system,
          child: Text('跟隨系統'),
        ),
      ],
    );
  }

  /// 漲跌配色慣例切換選單。
  Widget _BuildColorConventionMenu(DashboardController controller) {
    return PopupMenuButton<ProfitColorConvention>(
      tooltip: '漲跌配色',
      icon: const Icon(Icons.palette_outlined, size: 21),
      initialValue: controller.color_convention,
      onSelected: controller.SwitchProfitColorConvention,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<ProfitColorConvention>>[
        const PopupMenuItem<ProfitColorConvention>(
          value: ProfitColorConvention.us,
          child: Text('美股慣例：漲綠跌紅'),
        ),
        const PopupMenuItem<ProfitColorConvention>(
          value: ProfitColorConvention.taiwan,
          child: Text('台股慣例：漲紅跌綠'),
        ),
      ],
    );
  }

  /// 通用區塊卡片（深淺主題自動適應）。
  Widget _BuildSectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
    EdgeInsets padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    EdgeInsets title_padding = const EdgeInsets.fromLTRB(20, 18, 20, 14),
  }) {
    final AppColors colors = AppColors.Of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: title_padding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 12, color: colors.text_muted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  /// 已清倉個股卡片（僅顯示已實現損益）。
  Widget _BuildClosedPositionsCard(
      BuildContext context, DashboardController controller) {
    return _BuildSectionCard(
      context: context,
      title: '已清倉',
      child: Column(
        children: <Widget>[
          for (final HoldingPosition position
              in controller.GetClosedPositions())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Text(position.symbol,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    '已實現 ${position.realized_pnl >= 0 ? '+' : ''}'
                    '\$${position.realized_pnl.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: controller.profit_colors
                          .ResolveColorForValue(position.realized_pnl),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 開啟手動記帳對話框，成功新增後顯示提示。
  Future<void> _OpenAddTransactionDialog(
      BuildContext context, DashboardController controller) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? added = await AddTransactionDialog.Show(context, controller);
    if (added == true) {
      messenger.showSnackBar(const SnackBar(content: Text('交易已新增')));
    }
  }

  /*
   *  @fn      Future<void> _PickAndImportCsvFile(BuildContext context, DashboardController controller)
   *
   *  @brief   ( 開啟檔案選取器選擇 CSV，匯入後以 SnackBar 顯示統計結果 )
   *
   *  @note    匯入失敗或格式錯誤不會中斷 App，錯誤訊息一律以 SnackBar 呈現。
   */
  Future<void> _PickAndImportCsvFile(
      BuildContext context, DashboardController controller) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return; // 使用者取消
      }
      final PlatformFile file = result.files.first;
      final String csv_content = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: true)
          : await File(file.path!).readAsString();

      final ImportSummary summary =
          await controller.ImportCsvContent(csv_content);
      final String skipped_note = summary.skipped_rows.isNotEmpty
          ? '，跳過 ${summary.skipped_rows.length} 列（格式錯誤）'
          : '';
      messenger.showSnackBar(SnackBar(
        content: Text('匯入完成：新增 ${summary.inserted_count} 筆、'
            '重複略過 ${summary.duplicate_count} 筆$skipped_note'),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('匯入失敗：$error'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    }
  }
}

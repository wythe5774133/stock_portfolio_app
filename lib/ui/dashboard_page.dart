// 儀表板主頁：統計卡片、資產曲線、雙圓餅圖、持倉列表與工具列。

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/holding_position.dart';
import '../services/csv_transaction_importer.dart';
import 'dashboard_controller.dart';
import 'theme/profit_color_scheme.dart';
import 'widgets/add_transaction_dialog.dart';
import 'widgets/asset_curve_section.dart';
import 'widgets/holding_list_view.dart';
import 'widgets/holding_pie_chart.dart';
import 'widgets/quote_status_banner.dart';
import 'widgets/summary_stat_cards.dart';

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
      backgroundColor: const Color(0xFFF4F5F7),
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
                profit_colors: controller.profit_colors,
              ),
              const SizedBox(height: 16),
              _BuildSectionCard(
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
                title: '持倉明細',
                subtitle: '成本採${controller.cost_method_name}計算，點擊列展開交易明細',
                padding: EdgeInsets.zero,
                title_padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: HoldingListView(
                  rows: rows,
                  profit_colors: controller.profit_colors,
                ),
              ),
              if (controller.GetClosedPositions().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _BuildClosedPositionsCard(controller),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 頂部工具列：標題 + 更新 / 匯入 / 設定按鈕。
  Widget _BuildTopBar(BuildContext context, DashboardController controller) {
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
        _BuildColorConventionMenu(controller),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _PickAndImportCsvFile(context, controller),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('匯入 CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
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
            backgroundColor: const Color(0xFF111827),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
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

  /// 通用區塊卡片。
  Widget _BuildSectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
    EdgeInsets padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    EdgeInsets title_padding = const EdgeInsets.fromLTRB(20, 18, 20, 14),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAEE)),
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
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
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
  Widget _BuildClosedPositionsCard(DashboardController controller) {
    return _BuildSectionCard(
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

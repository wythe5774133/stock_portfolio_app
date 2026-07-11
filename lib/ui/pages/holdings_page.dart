// 持倉分頁：個股列表（可展開明細）與已清倉區塊。

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../models/holding_position.dart';
import '../../services/csv_transaction_importer.dart';
import '../dashboard_controller.dart';
import '../widgets/holding_list_view.dart';
import '../widgets/section_card.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HoldingsPage
 *
 * @brief   持倉分頁：持股列表、已清倉損益，與 CSV 匯入入口。
 */
class HoldingsPage extends StatelessWidget {
  final DashboardController controller;

  const HoldingsPage({super.key, required this.controller});

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
              SectionCard(
                title: '持倉明細',
                subtitle: '成本採${controller.cost_method_name}計算，點擊列展開交易明細',
                padding: EdgeInsets.zero,
                title_padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                trailing: TextButton.icon(
                  onPressed: () => PickAndImportCsvFile(context, controller),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('匯入 CSV', style: TextStyle(fontSize: 13)),
                ),
                child: HoldingListView(
                  rows: rows,
                  profit_colors: controller.profit_colors,
                  controller: controller,
                ),
              ),
              if (controller.GetClosedPositions().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                SectionCard(
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text(
                                '已實現 ${position.realized_pnl >= 0 ? '+' : ''}'
                                '\$${position.realized_pnl.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: controller.profit_colors
                                      .ResolveColorForValue(
                                          position.realized_pnl),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /*
   *  @fn      static Future<void> PickAndImportCsvFile(BuildContext context, DashboardController controller)
   *
   *  @brief   ( 開檔案選取器匯入 CSV，結果以 SnackBar 呈現；供多個分頁共用 )
   */
  static Future<void> PickAndImportCsvFile(
      BuildContext context, DashboardController controller) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          const XTypeGroup(label: 'CSV', extensions: <String>['csv']),
        ],
      );
      if (file == null) {
        return; // 使用者取消
      }
      final String csv_content =
          utf8.decode(await file.readAsBytes(), allowMalformed: true);

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

// 設定分頁：外觀、資料（股息開關、備份匯出匯入、CSV 匯入）與關於。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/backup_service.dart';
import '../dashboard_controller.dart';
import '../theme/app_theme.dart';
import '../theme/profit_color_scheme.dart';
import '../widgets/section_card.dart';
import 'holdings_page.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SettingsPage
 *
 * @brief   設定分頁：背景深淺、漲跌配色、股息追蹤開關、
 *          備份匯出/匯入、CSV 匯入與關於資訊。
 */
class SettingsPage extends StatelessWidget {
  final DashboardController controller;

  const SettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionCard(
                title: '外觀',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('背景深淺',
                          style: TextStyle(fontSize: 14.5)),
                      trailing: SegmentedButton<AppThemeMode>(
                        segments: const <ButtonSegment<AppThemeMode>>[
                          ButtonSegment<AppThemeMode>(
                              value: AppThemeMode.light, label: Text('淺色')),
                          ButtonSegment<AppThemeMode>(
                              value: AppThemeMode.dark, label: Text('深色')),
                          ButtonSegment<AppThemeMode>(
                              value: AppThemeMode.system, label: Text('系統')),
                        ],
                        selected: <AppThemeMode>{controller.theme_mode},
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                        onSelectionChanged: (Set<AppThemeMode> selection) {
                          controller.SwitchAppThemeMode(selection.first);
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('漲跌配色',
                          style: TextStyle(fontSize: 14.5)),
                      subtitle: Text('影響損益數字與 K 線顏色',
                          style: TextStyle(
                              fontSize: 11.5, color: colors.text_muted)),
                      trailing: SegmentedButton<ProfitColorConvention>(
                        segments: const <ButtonSegment<ProfitColorConvention>>[
                          ButtonSegment<ProfitColorConvention>(
                              value: ProfitColorConvention.us,
                              label: Text('漲綠跌紅')),
                          ButtonSegment<ProfitColorConvention>(
                              value: ProfitColorConvention.taiwan,
                              label: Text('漲紅跌綠')),
                        ],
                        selected: <ProfitColorConvention>{
                          controller.color_convention
                        },
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                        onSelectionChanged:
                            (Set<ProfitColorConvention> selection) {
                          controller
                              .SwitchProfitColorConvention(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '資料',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('股息追蹤',
                          style: TextStyle(fontSize: 14.5)),
                      subtitle: Text(
                        '券商有開股息再投資（DRIP）時請保持關閉，避免股息被重複計算；'
                        '開啟後統計卡會顯示累計股息，XIRR 亦含股息',
                        style: TextStyle(
                            fontSize: 11.5, color: colors.text_muted),
                      ),
                      value: controller.dividend_tracking_enabled,
                      onChanged: controller.SwitchDividendTracking,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download, size: 20),
                      title: const Text('匯入交易 CSV',
                          style: TextStyle(fontSize: 14.5)),
                      subtitle: Text('Yahoo Finance 匯出格式，自動去重',
                          style: TextStyle(
                              fontSize: 11.5, color: colors.text_muted)),
                      onTap: () => HoldingsPage.PickAndImportCsvFile(
                          context, controller),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.upload, size: 20),
                      title: const Text('匯出備份',
                          style: TextStyle(fontSize: 14.5)),
                      subtitle: Text('交易、追蹤清單與設定打包成一個檔案',
                          style: TextStyle(
                              fontSize: 11.5, color: colors.text_muted)),
                      onTap: () => ExportBackup(context),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restore, size: 20),
                      title: const Text('匯入備份',
                          style: TextStyle(fontSize: 14.5)),
                      subtitle: Text('合併模式：不會蓋掉現有資料，重複交易自動略過',
                          style: TextStyle(
                              fontSize: 11.5, color: colors.text_muted)),
                      onTap: () => ImportBackup(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '雲端同步',
                subtitle: '資料存在你自己 Google Drive 的 App 專屬隱藏空間，我們沒有伺服器',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _BuildDriveSyncSection(context, colors),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: '關於',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '股票庫存管理 App — 免費開源，資料全部存在本機。\n'
                      '持倉成本採${controller.cost_method_name}；'
                      '報價來自 Yahoo Finance 非官方端點，非即時無延遲資料。',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: colors.text_secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 雲端同步區塊：未登入顯示登入按鈕，已登入顯示帳號、同步狀態與操作。
  Widget _BuildDriveSyncSection(BuildContext context, AppColors colors) {
    if (!controller.is_drive_signed_in) {
      return Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined, size: 22),
            title: const Text('使用 Google 登入',
                style: TextStyle(fontSize: 14.5)),
            subtitle: Text(
              '登入後交易、追蹤清單與設定會自動同步到你的 Google Drive，'
              '其他裝置登入同一帳號即可雙向同步（刪除也會同步，不會復活）',
              style: TextStyle(fontSize: 11.5, color: colors.text_muted),
            ),
            onTap: () => _SignInToDrive(context),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined, size: 22),
          title: Text(controller.drive_account_email ?? '',
              style: const TextStyle(fontSize: 14.5)),
          subtitle: Text(
            controller.last_drive_sync_at != null
                ? '上次同步：'
                    '${DateFormat('yyyy/MM/dd HH:mm').format(controller.last_drive_sync_at!)}'
                : '尚未同步',
            style: TextStyle(fontSize: 11.5, color: colors.text_muted),
          ),
          trailing: controller.is_drive_syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: controller.is_drive_syncing
                  ? null
                  : () => _SyncDriveNow(context),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('立即同步', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => controller.SignOutGoogleDrive(),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('登出', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  /// 觸發 Google 登入並回報結果。
  Future<void> _SignInToDrive(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool signed_in = await controller.SignInToGoogleDrive();
    messenger.showSnackBar(SnackBar(
      content: Text(signed_in ? 'Google 登入成功，已完成首次同步' : '登入未完成'),
    ));
  }

  /// 手動觸發同步並回報結果。
  Future<void> _SyncDriveNow(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await controller.SyncWithDrive();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '同步完成' : '同步失敗，請檢查網路後再試'),
    ));
  }

  /// 匯出備份：產生 JSON 後開存檔對話框。
  Future<void> ExportBackup(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String backup_json = await controller.ExportBackupJson();
      final String file_name = 'stock_portfolio_backup_'
          '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
      final String? saved_path = await FilePicker.saveFile(
        fileName: file_name,
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        bytes: Uint8List.fromList(utf8.encode(backup_json)),
      );
      if (saved_path != null) {
        messenger.showSnackBar(const SnackBar(content: Text('備份已匯出')));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('匯出失敗：$error'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    }
  }

  /// 匯入備份：選檔後合併並顯示統計。
  Future<void> ImportBackup(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return; // 使用者取消
      }
      final PlatformFile file = result.files.first;
      final String backup_json = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();

      final BackupRestoreSummary summary =
          await controller.ImportBackupJson(backup_json);
      messenger.showSnackBar(SnackBar(
        content: Text('匯入完成：新增 ${summary.transactions_added} 筆交易'
            '（重複略過 ${summary.transactions_duplicated}）、'
            '新增 ${summary.watchlist_added} 檔追蹤'),
      ));
    } on FormatException catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('匯入失敗：${error.message}'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('匯入失敗：$error'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    }
  }
}

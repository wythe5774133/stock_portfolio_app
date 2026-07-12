// App 主外殼：響應式導覽——桌面（寬 ≥ 900）用左側導覽欄，
// 手機用底部分頁列。四個分頁：總覽、持倉、自選、設定。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_controller.dart';
import '../services/platform_io/env_reader.dart';
import 'pages/holdings_page.dart';
import 'pages/overview_page.dart';
import 'pages/settings_page.dart';
import 'pages/watchlist_page.dart';
import 'theme/app_theme.dart';
import 'widgets/add_transaction_dialog.dart';
import 'widgets/add_watchlist_dialog.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   HomeShell
 *
 * @brief   主導覽外殼：依畫面寬度自動切換側欄（桌面）與底部分頁（手機），
 *          並依目前分頁提供對應的主要動作按鈕（記一筆／加追蹤）。
 */
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const double DESKTOP_BREAKPOINT = 900;

  int selected_index = 0;

  @override
  void initState() {
    super.initState();
    // 開發輔助：模擬器 UI 驗證可用環境變數 INITIAL_TAB 指定啟始分頁（0~3）
    final int? initial_tab =
        int.tryParse(ReadEnvironmentVariable('INITIAL_TAB') ?? '');
    if (initial_tab != null && initial_tab >= 0 && initial_tab <= 3) {
      selected_index = initial_tab;
    }
  }

  static const List<(IconData, IconData, String)> DESTINATIONS =
      <(IconData, IconData, String)>[
    (Icons.dashboard_outlined, Icons.dashboard, '總覽'),
    (Icons.work_outline, Icons.work, '持倉'),
    (Icons.star_border, Icons.star, '自選'),
    (Icons.settings_outlined, Icons.settings, '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    final DashboardController controller =
        context.watch<DashboardController>();
    final AppColors colors = AppColors.Of(context);
    final bool is_desktop =
        MediaQuery.sizeOf(context).width >= DESKTOP_BREAKPOINT;

    if (controller.is_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Widget page = switch (selected_index) {
      0 => OverviewPage(controller: controller),
      1 => HoldingsPage(controller: controller),
      2 => WatchlistPage(controller: controller),
      _ => SettingsPage(controller: controller),
    };

    if (is_desktop) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: selected_index,
              onDestinationSelected: (int index) =>
                  setState(() => selected_index = index),
              labelType: NavigationRailLabelType.all,
              backgroundColor: colors.card_background,
              leading: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Image.asset(
                  'assets/icon/app_icon_macos.png',
                  width: 40,
                  height: 40,
                ),
              ),
              destinations: <NavigationRailDestination>[
                for (final (IconData, IconData, String) d in DESTINATIONS)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: colors.card_border),
            Expanded(
              child: Scaffold(
                appBar: _BuildAppBar(controller, colors),
                body: page,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _BuildAppBar(controller, colors),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected_index,
        onDestinationSelected: (int index) =>
            setState(() => selected_index = index),
        height: 64,
        destinations: <NavigationDestination>[
          for (final (IconData, IconData, String) d in DESTINATIONS)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }

  /// 頂部列：分頁標題＋對應的主要動作。
  PreferredSizeWidget _BuildAppBar(
      DashboardController controller, AppColors colors) {
    return AppBar(
      backgroundColor: colors.page_background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Text(
        DESTINATIONS[selected_index].$3 == '總覽'
            ? '股票庫存'
            : DESTINATIONS[selected_index].$3,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: '立即更新報價',
          onPressed: () => controller.RefreshQuotesNow(),
          icon: const Icon(Icons.refresh, size: 21),
        ),
        if (selected_index == 0 || selected_index == 1)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _OpenAddTransactionDialog(controller),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('記一筆'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary_button_background,
                foregroundColor: colors.primary_button_foreground,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        if (selected_index == 2)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => AddWatchlistDialog.Show(context, controller),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('追蹤'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary_button_background,
                foregroundColor: colors.primary_button_foreground,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
    );
  }

  /// 開手動記帳對話框，成功後提示。
  Future<void> _OpenAddTransactionDialog(
      DashboardController controller) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? added = await AddTransactionDialog.Show(context, controller);
    if (added == true) {
      messenger.showSnackBar(const SnackBar(content: Text('交易已新增')));
    }
  }
}

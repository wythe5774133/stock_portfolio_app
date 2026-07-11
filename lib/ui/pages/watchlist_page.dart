// 自選分頁：追蹤清單全頁。

import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../widgets/add_watchlist_dialog.dart';
import '../widgets/section_card.dart';
import '../widgets/watchlist_card.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   WatchlistPage
 *
 * @brief   自選分頁：追蹤清單與加入追蹤入口。
 */
class WatchlistPage extends StatelessWidget {
  final DashboardController controller;

  const WatchlistPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SectionCard(
            title: '追蹤清單',
            subtitle: '不需持有也能關注，點列查看 K 線與詳情',
            padding: EdgeInsets.zero,
            title_padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
            trailing: TextButton.icon(
              onPressed: () => AddWatchlistDialog.Show(context, controller),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('追蹤', style: TextStyle(fontSize: 13)),
            ),
            child: WatchlistCard(controller: controller),
          ),
        ),
      ),
    );
  }
}

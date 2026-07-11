// 加入追蹤對話框：搜尋代號後點選即加入追蹤清單。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/symbol_search_result.dart';
import '../dashboard_controller.dart';
import '../theme/app_theme.dart';
import 'watchlist_card.dart' show WatchlistGroupPicker;

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AddWatchlistDialog
 *
 * @brief   搜尋股票並加入追蹤清單：輸入去抖動 350ms，
 *          點選建議即完成加入並關閉對話框。
 */
class AddWatchlistDialog extends StatefulWidget {
  final DashboardController controller;

  const AddWatchlistDialog({super.key, required this.controller});

  /// 開啟對話框；回傳加入的代號（null = 取消）。
  static Future<String?> Show(
      BuildContext context, DashboardController controller) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          AddWatchlistDialog(controller: controller),
    );
  }

  @override
  State<AddWatchlistDialog> createState() => _AddWatchlistDialogState();
}

class _AddWatchlistDialogState extends State<AddWatchlistDialog> {
  final TextEditingController query_controller = TextEditingController();
  Timer? debounce_timer;
  List<SymbolSearchResult> results = <SymbolSearchResult>[];
  bool is_searching = false;

  @override
  void dispose() {
    debounce_timer?.cancel();
    query_controller.dispose();
    super.dispose();
  }

  /// 輸入變更：去抖動後搜尋。
  void OnQueryChanged(String query) {
    debounce_timer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => results = <SymbolSearchResult>[]);
      return;
    }
    debounce_timer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => is_searching = true);
      final List<SymbolSearchResult> search_results =
          await widget.controller.SearchSymbols(query);
      if (!mounted) {
        return;
      }
      setState(() {
        results = search_results;
        is_searching = false;
      });
    });
  }

  /// 點選建議：先選分類再加入追蹤並關閉。
  Future<void> OnResultSelected(SymbolSearchResult result) async {
    final String? group = await WatchlistGroupPicker.Show(
        context,
        widget.controller,
        widget.controller.selected_watchlist_group ?? '自選');
    if (group == null) {
      return; // 取消分類選擇 = 取消加入
    }
    await widget.controller
        .AddToWatchlist(result.symbol, result.name, group_name: group);
    if (mounted) {
      Navigator.of(context).pop(result.symbol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    return AlertDialog(
      title: const Text('加入追蹤',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: query_controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: '輸入代號或公司名稱（如 TSLA、台積電）',
                border: const OutlineInputBorder(),
                suffixIcon: is_searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: OnQueryChanged,
            ),
            if (results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.card_border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (BuildContext context, int index) {
                    final SymbolSearchResult result = results[index];
                    return ListTile(
                      dense: true,
                      title: Row(
                        children: <Widget>[
                          Text(result.symbol,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(result.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colors.text_secondary)),
                          ),
                        ],
                      ),
                      trailing: Text(result.exchange,
                          style: TextStyle(
                              fontSize: 11, color: colors.text_muted)),
                      onTap: () => OnResultSelected(result),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

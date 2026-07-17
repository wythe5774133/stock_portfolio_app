// 手動記帳對話框：代號搜尋自動完成 → 買/賣、價格、股數、日期輸入。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../logic/market_registry.dart';
import '../../models/stock_transaction.dart';
import '../../models/symbol_search_result.dart';
import '../dashboard_controller.dart';
import '../money_format.dart';
import '../theme/app_theme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AddTransactionDialog
 *
 * @brief   手動記帳表單：輸入代號會跳出搜尋建議（代號＋公司名稱），
 *          選定後自動帶入現價；買/賣切換、股數、日期（預設今天）。
 *
 * @note    搜尋輸入有 350ms 去抖動避免打字過程狂發請求；
 *          離線或搜尋失敗時仍可直接輸入代號存檔。
 */
class AddTransactionDialog extends StatefulWidget {
  final DashboardController controller;

  const AddTransactionDialog({super.key, required this.controller});

  /// 開啟對話框；回傳 true 表示成功新增一筆。
  static Future<bool?> Show(
      BuildContext context, DashboardController controller) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          AddTransactionDialog(controller: controller),
    );
  }

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final TextEditingController symbol_controller = TextEditingController();
  final TextEditingController price_controller = TextEditingController();
  final TextEditingController quantity_controller = TextEditingController();

  Timer? search_debounce_timer;
  List<SymbolSearchResult> search_results = <SymbolSearchResult>[];
  SymbolSearchResult? selected_symbol;
  bool is_searching = false;
  bool is_price_loading = false;
  bool is_saving = false;
  TransactionType transaction_type = TransactionType.buy;
  DateTime trade_date = DateTime.now();
  String? error_message;

  @override
  void dispose() {
    search_debounce_timer?.cancel();
    symbol_controller.dispose();
    price_controller.dispose();
    quantity_controller.dispose();
    super.dispose();
  }

  /// 代號輸入變更：去抖動後發搜尋。
  void OnSymbolQueryChanged(String query) {
    setState(() {
      selected_symbol = null; // 修改文字即取消先前選定
      error_message = null;
    });
    search_debounce_timer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => search_results = <SymbolSearchResult>[]);
      return;
    }
    search_debounce_timer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => is_searching = true);
      final List<SymbolSearchResult> results =
          await widget.controller.SearchSymbols(query);
      if (!mounted) {
        return;
      }
      setState(() {
        search_results = results;
        is_searching = false;
      });
    });
  }

  /// 使用者從建議清單選定股票：帶入代號並抓現價預填。
  Future<void> OnSymbolSelected(SymbolSearchResult result) async {
    setState(() {
      selected_symbol = result;
      symbol_controller.text = result.symbol;
      search_results = <SymbolSearchResult>[];
      is_price_loading = true;
    });
    final double? price =
        await widget.controller.FetchCurrentPriceForSymbol(result.symbol);
    if (!mounted) {
      return;
    }
    setState(() {
      is_price_loading = false;
      if (price != null && price_controller.text.trim().isEmpty) {
        price_controller.text = price.toStringAsFixed(2);
      }
    });
  }

  /// 開日曆選交易日期（不可選未來）。
  Future<void> OnPickTradeDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: trade_date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => trade_date = picked);
    }
  }

  /// 驗證並存檔。
  Future<void> OnSave() async {
    final String symbol = symbol_controller.text.trim().toUpperCase();
    final double? price = double.tryParse(price_controller.text.trim());
    final double? quantity = double.tryParse(quantity_controller.text.trim());

    if (symbol.isEmpty) {
      setState(() => error_message = '請輸入股票代號');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => error_message = '價格必須是大於 0 的數字');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => error_message = '股數必須是大於 0 的數字');
      return;
    }

    setState(() {
      is_saving = true;
      error_message = null;
    });
    final bool inserted =
        await widget.controller.AddManualTransaction(StockTransaction(
      symbol: symbol,
      trade_date: trade_date.year * 10000 +
          trade_date.month * 100 +
          trade_date.day,
      purchase_price: price,
      quantity: quantity,
      transaction_type: transaction_type,
    ));
    if (!mounted) {
      return;
    }
    if (!inserted) {
      setState(() {
        is_saving = false;
        error_message = '已有一筆相同的交易（代號、日期、價格、股數、類型皆相同）';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('記一筆交易',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BuildSymbolField(),
              if (search_results.isNotEmpty) _BuildSearchResultList(),
              const SizedBox(height: 14),
              _BuildTypeSelector(),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(child: _BuildPriceField()),
                  const SizedBox(width: 12),
                  Expanded(child: _BuildQuantityField()),
                ],
              ),
              const SizedBox(height: 14),
              _BuildDateField(),
              if (error_message != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(error_message!,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: is_saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: is_saving ? null : OnSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.Of(context).primary_button_background,
            foregroundColor: AppColors.Of(context).primary_button_foreground,
          ),
          child: is_saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('儲存'),
        ),
      ],
    );
  }

  /// 代號搜尋輸入框。
  Widget _BuildSymbolField() {
    return TextField(
      controller: symbol_controller,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: '股票代號',
        hintText: '輸入代號或公司名稱搜尋（如 NVDA、台積電）',
        border: const OutlineInputBorder(),
        suffixIcon: is_searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : (selected_symbol != null
                ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
                : const Icon(Icons.search)),
        helperText: selected_symbol != null
            ? '${selected_symbol!.name}（${selected_symbol!.exchange}）'
            : null,
      ),
      onChanged: OnSymbolQueryChanged,
    );
  }

  /// 搜尋建議清單。
  Widget _BuildSearchResultList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.Of(context).card_border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: search_results.length,
        separatorBuilder: (BuildContext context, int index) =>
            Divider(height: 1, color: AppColors.Of(context).divider),
        itemBuilder: (BuildContext context, int index) {
          final SymbolSearchResult result = search_results[index];
          return ListTile(
            dense: true,
            title: Row(
              children: <Widget>[
                Text(result.symbol,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.Of(context).text_secondary)),
                ),
              ],
            ),
            trailing: Text(result.exchange,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.Of(context).text_muted)),
            onTap: () => OnSymbolSelected(result),
          );
        },
      ),
    );
  }

  /// 買入/賣出切換。
  Widget _BuildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: const <ButtonSegment<TransactionType>>[
        ButtonSegment<TransactionType>(
            value: TransactionType.buy, label: Text('買入')),
        ButtonSegment<TransactionType>(
            value: TransactionType.sell, label: Text('賣出')),
      ],
      selected: <TransactionType>{transaction_type},
      onSelectionChanged: (Set<TransactionType> selection) {
        setState(() => transaction_type = selection.first);
      },
    );
  }

  /// 價格輸入框（選定股票後自動帶入現價，前綴依代號市場切換幣別）。
  Widget _BuildPriceField() {
    // 依目前輸入的代號判斷市場，即時切換幣別前綴（台股 NT$、美股 $）
    final String currency =
        ResolveMarketForSymbol(symbol_controller.text.trim()).currency;
    return TextField(
      controller: price_controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: '價格',
        prefixText: '${ResolveCurrencySymbol(currency)} ',
        border: const OutlineInputBorder(),
        suffixIcon: is_price_loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : null,
      ),
    );
  }

  /// 股數輸入框（支援碎股小數）。
  Widget _BuildQuantityField() {
    return TextField(
      controller: quantity_controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: const InputDecoration(
        labelText: '股數',
        hintText: '可輸入小數（碎股）',
        border: OutlineInputBorder(),
      ),
    );
  }

  /// 交易日期選擇（預設今天）。
  Widget _BuildDateField() {
    return OutlinedButton.icon(
      onPressed: OnPickTradeDate,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(DateFormat('yyyy/MM/dd').format(trade_date)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

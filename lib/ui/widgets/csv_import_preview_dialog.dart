// CSV 匯入確認視窗：讓使用者調整欄位對應並在寫入前檢查解析結果。

import 'package:flutter/material.dart';

import '../../logic/market_registry.dart';
import '../../models/stock_transaction.dart';
import '../../services/csv_transaction_importer.dart';
import '../dashboard_controller.dart';
import '../money_format.dart';
import '../theme/app_theme.dart';

class CsvImportPreviewDialog extends StatefulWidget {
  final String csv_content;
  final DashboardController controller;

  const CsvImportPreviewDialog({
    super.key,
    required this.csv_content,
    required this.controller,
  });

  @override
  State<CsvImportPreviewDialog> createState() => _CsvImportPreviewDialogState();
}

class _CsvImportPreviewDialogState extends State<CsvImportPreviewDialog> {
  late final List<String> headers;
  late CsvColumnMapping mapping;

  @override
  void initState() {
    super.initState();
    headers = widget.controller.GetCsvHeaders(widget.csv_content);
    mapping = widget.controller.SuggestCsvColumnMapping(headers);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final CsvParseResult preview = widget.controller.PreviewCsvContent(
      widget.csv_content,
      mapping,
    );
    return AlertDialog(
      title: const Text('確認 CSV 匯入'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '欄位對應',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.text_primary,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double field_width = constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _BuildRequiredField(
                        '股票代號',
                        mapping.symbol,
                        field_width,
                        _SetSymbol,
                      ),
                      _BuildRequiredField(
                        '交易日期',
                        mapping.trade_date,
                        field_width,
                        _SetTradeDate,
                      ),
                      _BuildRequiredField(
                        '成交價格',
                        mapping.purchase_price,
                        field_width,
                        _SetPrice,
                      ),
                      _BuildRequiredField(
                        '數量',
                        mapping.quantity,
                        field_width,
                        _SetQuantity,
                      ),
                      _BuildRequiredField(
                        '買賣類型',
                        mapping.transaction_type,
                        field_width,
                        _SetType,
                      ),
                      _BuildOptionalField(
                        '手續費（選填）',
                        mapping.commission,
                        field_width,
                        _SetCommission,
                      ),
                      _BuildOptionalField(
                        '備註（選填）',
                        mapping.comment,
                        field_width,
                        _SetComment,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.subtle_background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.card_border),
                ),
                child: Text(
                  mapping.has_required_columns
                      ? '可匯入 ${preview.transactions.length} 筆，'
                            '跳過 ${preview.skipped_rows.length} 列'
                      : '請完成五個必要欄位的對應',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text_primary,
                  ),
                ),
              ),
              if (preview.transactions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  '前 5 筆預覽',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.text_primary,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 36,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('代號')),
                      DataColumn(label: Text('日期')),
                      DataColumn(label: Text('類型')),
                      DataColumn(label: Text('價格')),
                      DataColumn(label: Text('數量')),
                    ],
                    rows: <DataRow>[
                      for (final StockTransaction transaction
                          in preview.transactions.take(5))
                        DataRow(
                          cells: <DataCell>[
                            DataCell(Text(transaction.symbol)),
                            DataCell(Text(transaction.trade_date.toString())),
                            DataCell(
                              Text(
                                FormatTransactionType(
                                  transaction.transaction_type,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                // 原生幣別前綴（台股 NT$、美股 $），保留 4 位精度
                                '${ResolveCurrencySymbol(ResolveMarketForSymbol(transaction.symbol).currency)}'
                                '${transaction.purchase_price.toStringAsFixed(4)}',
                              ),
                            ),
                            DataCell(Text(transaction.quantity.toString())),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (preview.skipped_rows.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  preview.skipped_rows
                      .take(3)
                      .map((SkippedCsvRow row) => row.toString())
                      .join('\n'),
                  style: TextStyle(fontSize: 12, color: colors.text_secondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              mapping.has_required_columns && preview.transactions.isNotEmpty
              ? () => Navigator.of(context).pop(mapping)
              : null,
          child: Text('匯入 ${preview.transactions.length} 筆'),
        ),
      ],
    );
  }

  Widget _BuildRequiredField(
    String label,
    String? value,
    double width,
    ValueChanged<String> on_changed,
  ) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '$label *',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: <DropdownMenuItem<String>>[
          for (final String header in headers)
            DropdownMenuItem<String>(value: header, child: Text(header)),
        ],
        onChanged: (String? selected) {
          if (selected != null) {
            on_changed(selected);
          }
        },
      ),
    );
  }

  Widget _BuildOptionalField(
    String label,
    String? value,
    double width,
    ValueChanged<String?> on_changed,
  ) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: null, child: Text('不匯入')),
          for (final String header in headers)
            DropdownMenuItem<String>(value: header, child: Text(header)),
        ],
        onChanged: on_changed,
      ),
    );
  }

  void _SetSymbol(String value) {
    setState(() => mapping = mapping.CopyWith(symbol: value));
  }

  void _SetTradeDate(String value) {
    setState(() => mapping = mapping.CopyWith(trade_date: value));
  }

  void _SetPrice(String value) {
    setState(() => mapping = mapping.CopyWith(purchase_price: value));
  }

  void _SetQuantity(String value) {
    setState(() => mapping = mapping.CopyWith(quantity: value));
  }

  void _SetType(String value) {
    setState(() => mapping = mapping.CopyWith(transaction_type: value));
  }

  void _SetCommission(String? value) {
    setState(
      () => mapping = mapping.CopyWith(
        commission: value,
        clear_commission: value == null,
      ),
    );
  }

  void _SetComment(String? value) {
    setState(
      () => mapping = mapping.CopyWith(
        comment: value,
        clear_comment: value == null,
      ),
    );
  }
}

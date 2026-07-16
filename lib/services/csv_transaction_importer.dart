// CSV 交易紀錄匯入器：解析 Yahoo Finance 匯出格式的逐筆交易 CSV，
// 只取交易必要欄位，忽略即時報價快照欄位，並支援去重匯入。

import 'package:csv/csv.dart';

import '../database/transaction_dao.dart';
import '../models/stock_transaction.dart';

/// 單一被跳過的 CSV 列與原因。
class SkippedCsvRow {
  final int row_number; // CSV 中的列號（含標題列，從 1 起算）
  final String reason; // 跳過原因（繁中描述）

  const SkippedCsvRow({required this.row_number, required this.reason});

  @override
  String toString() => '第 $row_number 列：$reason';
}

/// CSV 解析結果：成功解析的交易與被跳過的列。
class CsvParseResult {
  final List<StockTransaction> transactions;
  final List<SkippedCsvRow> skipped_rows;

  const CsvParseResult({
    required this.transactions,
    required this.skipped_rows,
  });
}

/// CSV 原始欄位與 App 交易欄位的對應關係。
class CsvColumnMapping {
  final String? symbol;
  final String? trade_date;
  final String? purchase_price;
  final String? quantity;
  final String? transaction_type;
  final String? commission;
  final String? comment;

  const CsvColumnMapping({
    required this.symbol,
    required this.trade_date,
    required this.purchase_price,
    required this.quantity,
    required this.transaction_type,
    this.commission,
    this.comment,
  });

  bool get has_required_columns =>
      symbol != null &&
      trade_date != null &&
      purchase_price != null &&
      quantity != null &&
      transaction_type != null;

  CsvColumnMapping CopyWith({
    String? symbol,
    String? trade_date,
    String? purchase_price,
    String? quantity,
    String? transaction_type,
    String? commission,
    String? comment,
    bool clear_commission = false,
    bool clear_comment = false,
  }) {
    return CsvColumnMapping(
      symbol: symbol ?? this.symbol,
      trade_date: trade_date ?? this.trade_date,
      purchase_price: purchase_price ?? this.purchase_price,
      quantity: quantity ?? this.quantity,
      transaction_type: transaction_type ?? this.transaction_type,
      commission: clear_commission ? null : commission ?? this.commission,
      comment: clear_comment ? null : comment ?? this.comment,
    );
  }
}

/// 匯入資料庫後的統計摘要。
class ImportSummary {
  final int inserted_count; // 實際新增筆數
  final int duplicate_count; // 因重複被忽略的筆數
  final List<SkippedCsvRow> skipped_rows; // 解析階段被跳過的列

  const ImportSummary({
    required this.inserted_count,
    required this.duplicate_count,
    required this.skipped_rows,
  });
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   CsvTransactionImporter
 *
 * @brief   解析交易紀錄 CSV 並匯入資料庫（去重）。
 *
 * @note    CSV 欄位固定為 Yahoo Finance 匯出格式，僅解析
 *          Symbol / Trade Date / Purchase Price / Quantity / Transaction Type
 *          （Commission、Comment 選填），其餘報價快照欄位一律忽略。
 *          格式錯誤的列跳過並記錄原因，不會使整體匯入失敗。
 */
class CsvTransactionImporter {
  static const String COLUMN_SYMBOL = 'Symbol';
  static const String COLUMN_TRADE_DATE = 'Trade Date';
  static const String COLUMN_PURCHASE_PRICE = 'Purchase Price';
  static const String COLUMN_QUANTITY = 'Quantity';
  static const String COLUMN_TRANSACTION_TYPE = 'Transaction Type';
  static const String COLUMN_COMMISSION = 'Commission';
  static const String COLUMN_COMMENT = 'Comment';

  static const Map<String, List<String>> COLUMN_ALIASES =
      <String, List<String>>{
        COLUMN_SYMBOL: <String>['Symbol', 'Ticker', '股票代號', '代號'],
        COLUMN_TRADE_DATE: <String>['Trade Date', 'Date', '交易日期', '成交日期'],
        COLUMN_PURCHASE_PRICE: <String>['Purchase Price', 'Price', '成交價', '價格'],
        COLUMN_QUANTITY: <String>['Quantity', 'Shares', '數量', '股數'],
        COLUMN_TRANSACTION_TYPE: <String>[
          'Transaction Type',
          'Type',
          'Action',
          '交易類型',
          '買賣別',
        ],
        COLUMN_COMMISSION: <String>['Commission', 'Fee', '手續費'],
        COLUMN_COMMENT: <String>['Comment', 'Note', '備註'],
      };

  /// 讀取 CSV 標題列，供匯入預覽與欄位對應選單使用。
  List<String> GetCsvHeaders(String csv_content) {
    final List<List<dynamic>> rows = Csv(
      lineDelimiter: '\n',
      dynamicTyping: false,
    ).decode(csv_content.replaceAll('\r\n', '\n'));
    if (rows.isEmpty) {
      return <String>[];
    }
    return rows.first
        .map(
          (dynamic cell) => cell.toString().replaceFirst('\ufeff', '').trim(),
        )
        .where((String header) => header.isNotEmpty)
        .toList();
  }

  /// 依常見中英文欄位別名自動建立欄位對應。
  CsvColumnMapping SuggestColumnMapping(List<String> headers) {
    String? FindAlias(String canonical_name) {
      final List<String> aliases = COLUMN_ALIASES[canonical_name]!;
      // 別名依優先順序搜尋，避免 Yahoo 同時含 Date 與 Trade Date 時誤選 Date。
      for (final String alias in aliases) {
        for (final String header in headers) {
          if (alias.toLowerCase() == header.trim().toLowerCase()) {
            return header;
          }
        }
      }
      return null;
    }

    return CsvColumnMapping(
      symbol: FindAlias(COLUMN_SYMBOL),
      trade_date: FindAlias(COLUMN_TRADE_DATE),
      purchase_price: FindAlias(COLUMN_PURCHASE_PRICE),
      quantity: FindAlias(COLUMN_QUANTITY),
      transaction_type: FindAlias(COLUMN_TRANSACTION_TYPE),
      commission: FindAlias(COLUMN_COMMISSION),
      comment: FindAlias(COLUMN_COMMENT),
    );
  }

  /*
   *  @fn      CsvParseResult ParseCsvTransactions(String csv_content)
   *
   *  @brief   ( 將 CSV 全文解析為交易紀錄清單 )
   *
   *  @param   csv_content - CSV 檔案全文
   *
   *  @return  CsvParseResult - 成功解析的交易與被跳過列的清單
   *
   *  @note    標題列缺少必要欄位時，回傳全空並以第 1 列錯誤記錄原因。
   */
  CsvParseResult ParseCsvTransactions(
    String csv_content, {
    CsvColumnMapping? column_mapping,
  }) {
    final List<StockTransaction> transactions = <StockTransaction>[];
    final List<SkippedCsvRow> skipped = <SkippedCsvRow>[];

    // csv 8.x：dynamicTyping 關閉表示所有欄位維持字串，由本類別自行做強型別轉換
    final List<List<dynamic>> raw_rows = Csv(
      lineDelimiter: '\n',
      dynamicTyping: false,
    ).decode(csv_content.replaceAll('\r\n', '\n'));
    final List<List<String>> rows = raw_rows
        .map(
          (List<dynamic> row) =>
              row.map((dynamic cell) => cell.toString()).toList(),
        )
        .toList();

    if (rows.isEmpty) {
      skipped.add(const SkippedCsvRow(row_number: 1, reason: 'CSV 內容為空'));
      return CsvParseResult(transactions: transactions, skipped_rows: skipped);
    }

    // 依標題列名稱找出各欄位索引，容忍前後空白
    final List<String> header = rows.first
        .map((String h) => h.replaceFirst('\ufeff', '').trim())
        .toList();
    final CsvColumnMapping mapping =
        column_mapping ?? SuggestColumnMapping(header);
    int FindHeaderIndex(String? selected_header) {
      if (selected_header == null) {
        return -1;
      }
      return header.indexWhere(
        (String value) =>
            value.toLowerCase() == selected_header.trim().toLowerCase(),
      );
    }

    final int symbol_index = FindHeaderIndex(mapping.symbol);
    final int trade_date_index = FindHeaderIndex(mapping.trade_date);
    final int price_index = FindHeaderIndex(mapping.purchase_price);
    final int quantity_index = FindHeaderIndex(mapping.quantity);
    final int type_index = FindHeaderIndex(mapping.transaction_type);
    final int commission_index = FindHeaderIndex(mapping.commission);
    final int comment_index = FindHeaderIndex(mapping.comment);

    if (symbol_index < 0 ||
        trade_date_index < 0 ||
        price_index < 0 ||
        quantity_index < 0 ||
        type_index < 0) {
      skipped.add(
        const SkippedCsvRow(
          row_number: 1,
          reason:
              '標題列缺少必要欄位（Symbol / Trade Date / Purchase Price / '
              'Quantity / Transaction Type）',
        ),
      );
      return CsvParseResult(transactions: transactions, skipped_rows: skipped);
    }

    for (int i = 1; i < rows.length; i++) {
      final int row_number = i + 1;
      final List<String> row = rows[i];

      // 跳過完全空白的列
      if (row.every((String cell) => cell.trim().isEmpty)) {
        continue;
      }

      final int max_required_index = <int>[
        symbol_index,
        trade_date_index,
        price_index,
        quantity_index,
        type_index,
      ].reduce((int a, int b) => a > b ? a : b);
      if (row.length <= max_required_index) {
        skipped.add(
          SkippedCsvRow(
            row_number: row_number,
            reason: '欄位數不足（${row.length} 欄）',
          ),
        );
        continue;
      }

      final String symbol = row[symbol_index].trim().toUpperCase();
      if (symbol.isEmpty) {
        skipped.add(SkippedCsvRow(row_number: row_number, reason: 'Symbol 為空'));
        continue;
      }

      final int? trade_date = ParseTradeDate(row[trade_date_index]);
      if (trade_date == null) {
        skipped.add(
          SkippedCsvRow(
            row_number: row_number,
            reason: 'Trade Date 格式錯誤：「${row[trade_date_index]}」',
          ),
        );
        continue;
      }

      final double? price = double.tryParse(row[price_index].trim());
      if (price == null || price <= 0) {
        skipped.add(
          SkippedCsvRow(
            row_number: row_number,
            reason: 'Purchase Price 無效：「${row[price_index]}」',
          ),
        );
        continue;
      }

      final double? quantity = double.tryParse(row[quantity_index].trim());
      if (quantity == null || quantity <= 0) {
        skipped.add(
          SkippedCsvRow(
            row_number: row_number,
            reason: 'Quantity 無效：「${row[quantity_index]}」',
          ),
        );
        continue;
      }

      final TransactionType? type = ParseTransactionType(row[type_index]);
      if (type == null) {
        skipped.add(
          SkippedCsvRow(
            row_number: row_number,
            reason: 'Transaction Type 無效：「${row[type_index]}」',
          ),
        );
        continue;
      }

      final double? commission =
          (commission_index >= 0 &&
              commission_index < row.length &&
              row[commission_index].trim().isNotEmpty)
          ? double.tryParse(row[commission_index].trim())
          : null;
      final String? comment =
          (comment_index >= 0 &&
              comment_index < row.length &&
              row[comment_index].trim().isNotEmpty)
          ? row[comment_index].trim()
          : null;

      transactions.add(
        StockTransaction(
          symbol: symbol,
          trade_date: trade_date,
          purchase_price: price,
          quantity: quantity,
          transaction_type: type,
          commission: commission,
          comment: comment,
        ),
      );
    }

    return CsvParseResult(transactions: transactions, skipped_rows: skipped);
  }

  /*
   *  @fn      Future<ImportSummary> ImportCsvIntoDatabase(String csv_content, TransactionDao transaction_dao)
   *
   *  @brief   ( 解析 CSV 並將交易去重寫入資料庫 )
   *
   *  @param   csv_content - CSV 檔案全文
   *  @param   transaction_dao - 交易表 DAO
   *
   *  @return  ImportSummary - 新增/重複/跳過統計
   *
   *  @note    重複判斷依據 (symbol, trade_date, price, quantity, type) 唯一鍵，
   *           同一份 CSV 重複匯入不會產生重複紀錄。
   */
  Future<ImportSummary> ImportCsvIntoDatabase(
    String csv_content,
    TransactionDao transaction_dao, {
    CsvColumnMapping? column_mapping,
  }) async {
    final CsvParseResult parse_result = ParseCsvTransactions(
      csv_content,
      column_mapping: column_mapping,
    );
    int inserted = 0;
    int duplicated = 0;
    for (final StockTransaction transaction in parse_result.transactions) {
      final bool was_inserted = await transaction_dao.InsertIgnoreTransaction(
        transaction,
      );
      if (was_inserted) {
        inserted++;
      } else {
        duplicated++;
      }
    }
    return ImportSummary(
      inserted_count: inserted,
      duplicate_count: duplicated,
      skipped_rows: parse_result.skipped_rows,
    );
  }

  /// 解析交易日期為 yyyyMMdd 整數；接受「20260707」或「2026/07/07」「2026-07-07」。
  static int? ParseTradeDate(String raw) {
    final String digits = raw.trim().replaceAll(RegExp(r'[/\-]'), '');
    if (digits.length != 8) {
      return null;
    }
    final int? value = int.tryParse(digits);
    if (value == null) {
      return null;
    }
    final int month = (value ~/ 100) % 100;
    final int day = value % 100;
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return value;
  }
}

// 手動驗證工具：把範例 CSV 直接匯入指定路徑的 SQLite 資料庫，
// 用於在不操作 GUI 檔案選取器的情況下預先填充 App 資料。
// 執行：dart run tool/seed_database.dart <資料庫路徑> <CSV路徑>
// ignore_for_file: avoid_print — 本檔為手動驗證 CLI 工具，print 即輸出介面

import 'dart:io';

import 'package:drift/native.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/services/csv_transaction_importer.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    print('用法：dart run tool/seed_database.dart <資料庫路徑> <CSV路徑>');
    exitCode = 64;
    return;
  }
  final AppDatabase database = AppDatabase(NativeDatabase(File(args[0])));
  final String csv_content = File(args[1]).readAsStringSync();
  final ImportSummary summary = await CsvTransactionImporter()
      .ImportCsvIntoDatabase(csv_content, database.transactionDao);
  print('新增 ${summary.inserted_count} 筆、重複 ${summary.duplicate_count} 筆、'
      '跳過 ${summary.skipped_rows.length} 列');
  await database.close();
}

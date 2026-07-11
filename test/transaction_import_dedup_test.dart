// 匯入去重整合測試：以記憶體 SQLite 實測「同一份 CSV 重複匯入不產生重複紀錄」。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/logic/portfolio_calculator.dart';
import 'package:stock_portfolio_app/models/holding_position.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/csv_transaction_importer.dart';

void main() {
  late AppDatabase database;
  late CsvTransactionImporter importer;
  late String csv_content;

  setUp(() {
    database = AppDatabase.Memory();
    importer = CsvTransactionImporter();
    csv_content =
        File('test/fixtures/sample_transactions.csv').readAsStringSync();
  });

  tearDown(() async {
    await database.close();
  });

  test('首次匯入：全部 11 筆新增', () async {
    final ImportSummary summary = await importer.ImportCsvIntoDatabase(
        csv_content, database.transactionDao);
    expect(summary.inserted_count, 11);
    expect(summary.duplicate_count, 0);
    expect(summary.skipped_rows, isEmpty);

    final List<StockTransaction> all =
        await database.transactionDao.GetAllTransactions();
    expect(all.length, 11);
  });

  test('重複匯入同一份 CSV：0 新增、11 重複、持倉數字不變', () async {
    await importer.ImportCsvIntoDatabase(csv_content, database.transactionDao);

    final PortfolioCalculator calculator = PortfolioCalculator();
    final List<HoldingPosition> before = calculator.CalculateHoldingPositions(
        await database.transactionDao.GetAllTransactions());

    final ImportSummary second = await importer.ImportCsvIntoDatabase(
        csv_content, database.transactionDao);
    expect(second.inserted_count, 0);
    expect(second.duplicate_count, 11);

    final List<StockTransaction> all =
        await database.transactionDao.GetAllTransactions();
    expect(all.length, 11);

    final List<HoldingPosition> after =
        calculator.CalculateHoldingPositions(all);
    expect(after.length, before.length);
    for (int i = 0; i < after.length; i++) {
      expect(after[i].net_quantity, closeTo(before[i].net_quantity, 1e-12));
      expect(after[i].average_cost, closeTo(before[i].average_cost, 1e-12));
      expect(after[i].realized_pnl, closeTo(before[i].realized_pnl, 1e-12));
    }
  });

  test('部分重疊的 CSV：只新增新交易', () async {
    await importer.ImportCsvIntoDatabase(csv_content, database.transactionDao);

    // 原有 11 筆 + 1 筆新交易
    final String extended = '$csv_content'
        'TSLA,300.0,2026/07/10,16:00 EDT,1,1,1,1,1,20260701,295.5,1.0,,,,,BUY\n';
    final ImportSummary summary = await importer.ImportCsvIntoDatabase(
        extended, database.transactionDao);
    expect(summary.inserted_count, 1);
    expect(summary.duplicate_count, 11);

    final List<StockTransaction> all =
        await database.transactionDao.GetAllTransactions();
    expect(all.length, 12);
  });

  test('依代號查詢交易明細（依日期排序）', () async {
    await importer.ImportCsvIntoDatabase(csv_content, database.transactionDao);
    final List<StockTransaction> nvda =
        await database.transactionDao.GetTransactionsBySymbol('NVDA');
    expect(nvda.length, 4);
    for (int i = 1; i < nvda.length; i++) {
      expect(nvda[i].trade_date, greaterThanOrEqualTo(nvda[i - 1].trade_date));
    }
  });
}

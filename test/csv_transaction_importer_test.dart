// CsvTransactionImporter 單元測試：正常解析、壞列跳過、日期格式容錯。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/csv_transaction_importer.dart';

void main() {
  final CsvTransactionImporter importer = CsvTransactionImporter();

  group('ParseCsvTransactions - 範例 fixture', () {
    late CsvParseResult result;

    setUpAll(() {
      final String csv_content = File(
        'test/fixtures/sample_transactions.csv',
      ).readAsStringSync();
      result = importer.ParseCsvTransactions(csv_content);
    });

    test('全部 11 筆交易成功解析，無跳過', () {
      expect(result.transactions.length, 11);
      expect(result.skipped_rows, isEmpty);
    });

    test('第一筆 NVDA BUY 的欄位值正確（只取交易欄位，忽略報價快照欄位）', () {
      final StockTransaction first = result.transactions.first;
      expect(first.symbol, 'NVDA');
      expect(first.trade_date, 20260707);
      expect(first.purchase_price, closeTo(194.478914, 1e-9));
      expect(first.quantity, closeTo(0.77129, 1e-9));
      expect(first.transaction_type, TransactionType.buy);
    });

    test('SELL 列正確解析', () {
      final StockTransaction sell = result.transactions.firstWhere(
        (StockTransaction t) =>
            t.transaction_type == TransactionType.sell && t.symbol == 'NVDA',
      );
      expect(sell.trade_date, 20260613);
      expect(sell.purchase_price, closeTo(205.0, 1e-9));
      expect(sell.quantity, closeTo(0.41538, 1e-9));
    });
  });

  group('ParseCsvTransactions - 錯誤處理', () {
    const String header =
        'Symbol,Current Price,Date,Time,Change,Open,High,Low,Volume,'
        'Trade Date,Purchase Price,Quantity,Commission,High Limit,Low Limit,'
        'Comment,Transaction Type';

    test('壞列跳過且記錄原因，好列照常解析', () {
      final String csv_content = <String>[
        header,
        // 好列
        'NVDA,1,1,1,1,1,1,1,1,20260101,100.0,1.0,,,,,BUY',
        // 日期錯誤
        'NVDA,1,1,1,1,1,1,1,1,not-a-date,100.0,1.0,,,,,BUY',
        // 數量無效
        'NVDA,1,1,1,1,1,1,1,1,20260102,100.0,-3,,,,,BUY',
        // 交易類型無效
        'NVDA,1,1,1,1,1,1,1,1,20260103,100.0,1.0,,,,,HOLD',
        // Symbol 為空
        ',1,1,1,1,1,1,1,1,20260104,100.0,1.0,,,,,BUY',
        // 好列（小寫 type 也要能解析）
        'voo,1,1,1,1,1,1,1,1,20260105,500.0,2.0,,,,,sell',
      ].join('\n');

      final CsvParseResult result = importer.ParseCsvTransactions(csv_content);
      expect(result.transactions.length, 2);
      expect(result.skipped_rows.length, 4);
      expect(result.transactions[0].symbol, 'NVDA');
      // Symbol 統一轉大寫、type 不分大小寫
      expect(result.transactions[1].symbol, 'VOO');
      expect(result.transactions[1].transaction_type, TransactionType.sell);
    });

    test('標題列缺少必要欄位時整體回報錯誤', () {
      final CsvParseResult result = importer.ParseCsvTransactions(
        'Symbol,Foo\nNVDA,1',
      );
      expect(result.transactions, isEmpty);
      expect(result.skipped_rows.length, 1);
      expect(result.skipped_rows.first.reason, contains('必要欄位'));
    });

    test('空內容不噴例外', () {
      final CsvParseResult result = importer.ParseCsvTransactions('');
      expect(result.transactions, isEmpty);
      expect(result.skipped_rows, isNotEmpty);
    });
  });

  group('ParseTradeDate - 日期格式容錯', () {
    test('yyyyMMdd 整數格式', () {
      expect(CsvTransactionImporter.ParseTradeDate('20260707'), 20260707);
    });
    test('斜線與連字號格式', () {
      expect(CsvTransactionImporter.ParseTradeDate('2026/07/07'), 20260707);
      expect(CsvTransactionImporter.ParseTradeDate('2026-07-07'), 20260707);
    });
    test('無效月日拒絕', () {
      expect(CsvTransactionImporter.ParseTradeDate('20261307'), isNull);
      expect(CsvTransactionImporter.ParseTradeDate('20260732'), isNull);
      expect(CsvTransactionImporter.ParseTradeDate('abc'), isNull);
    });
  });

  group('欄位對應與常見別名', () {
    test('可自動辨識繁中標題', () {
      const String csv_content =
          '股票代號,交易日期,成交價,股數,買賣別,手續費,備註\n'
          'AAPL,2026-01-02,200,2,BUY,1.5,首次買入';
      final List<String> headers = importer.GetCsvHeaders(csv_content);
      final CsvColumnMapping mapping = importer.SuggestColumnMapping(headers);
      final CsvParseResult result = importer.ParseCsvTransactions(
        csv_content,
        column_mapping: mapping,
      );
      expect(mapping.has_required_columns, isTrue);
      expect(result.transactions.single.symbol, 'AAPL');
      expect(result.transactions.single.commission, 1.5);
      expect(result.transactions.single.comment, '首次買入');
    });

    test('可手動對應非標準欄位名稱', () {
      const String csv_content =
          'code,when,unit_price,shares,side\nTSLA,20260103,400,3,SELL';
      const CsvColumnMapping mapping = CsvColumnMapping(
        symbol: 'code',
        trade_date: 'when',
        purchase_price: 'unit_price',
        quantity: 'shares',
        transaction_type: 'side',
      );
      final CsvParseResult result = importer.ParseCsvTransactions(
        csv_content,
        column_mapping: mapping,
      );
      expect(result.transactions.single.symbol, 'TSLA');
      expect(result.transactions.single.transaction_type, TransactionType.sell);
    });
  });
}

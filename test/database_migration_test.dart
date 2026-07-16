// 資料庫遷移測試：以真實舊版 SQLite schema 建檔，再由目前 AppDatabase 開啟升級。

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

void main() {
  late Directory temp_directory;

  setUp(() {
    temp_directory = Directory.systemTemp.createTempSync('migration_test');
  });

  tearDown(() {
    temp_directory.deleteSync(recursive: true);
  });

  test('v1 交易資料可直接升級到 v5 且內容完整保留', () async {
    final File database_file = File('${temp_directory.path}/v1.sqlite');
    final AppDatabase database = AppDatabase(
      NativeDatabase(
        database_file,
        setup: (dynamic raw_database) {
          raw_database.execute('''
          CREATE TABLE stock_transactions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL,
            trade_date INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            quantity REAL NOT NULL,
            transaction_type TEXT NOT NULL,
            commission REAL NULL,
            comment TEXT NULL,
            UNIQUE(symbol, trade_date, purchase_price, quantity, transaction_type)
          );
        ''');
          raw_database.execute('''
          CREATE TABLE quote_cache (
            symbol TEXT NOT NULL PRIMARY KEY,
            regular_price REAL NULL,
            regular_time INTEGER NULL,
            pre_price REAL NULL,
            pre_time INTEGER NULL,
            post_price REAL NULL,
            post_time INTEGER NULL,
            previous_close REAL NULL,
            market_state TEXT NULL,
            fetched_at INTEGER NOT NULL
          );
        ''');
          raw_database.execute('''
          CREATE TABLE historical_prices (
            symbol TEXT NOT NULL,
            date INTEGER NOT NULL,
            close_price REAL NOT NULL,
            UNIQUE(symbol, date)
          );
        ''');
          raw_database.execute('''
          INSERT INTO stock_transactions
            (symbol, trade_date, purchase_price, quantity, transaction_type)
          VALUES ('NVDA', 20220103, 30.5, 4.0, 'BUY');
        ''');
          raw_database.execute('PRAGMA user_version = 1;');
        },
      ),
    );

    final List<StockTransactionRow> rows = await database
        .select(database.stockTransactions)
        .get();
    expect(rows.single.symbol, 'NVDA');
    expect(rows.single.trade_date, 20220103);
    expect(await database.select(database.dividendEvents).get(), isEmpty);
    expect(await database.select(database.watchlistSymbols).get(), isEmpty);
    expect(await database.select(database.syncTombstones).get(), isEmpty);
    await database.close();
  });

  test('v3 追蹤清單升級後自動取得預設分類', () async {
    final File database_file = File('${temp_directory.path}/v3.sqlite');
    final AppDatabase database = AppDatabase(
      NativeDatabase(
        database_file,
        setup: (dynamic raw_database) {
          raw_database.execute('''
          CREATE TABLE watchlist_symbols (
            symbol TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            added_at INTEGER NOT NULL
          );
        ''');
          raw_database.execute('''
          INSERT INTO watchlist_symbols (symbol, name, added_at)
          VALUES ('VOO', 'Vanguard S&P 500 ETF', 1);
        ''');
          raw_database.execute('PRAGMA user_version = 3;');
        },
      ),
    );

    final List<WatchlistSymbol> rows = await database
        .select(database.watchlistSymbols)
        .get();
    expect(rows.single.symbol, 'VOO');
    expect(rows.single.group_name, '自選');
    await database.close();
  });
}

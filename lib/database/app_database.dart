// drift 資料庫 schema 定義：交易、報價快取、歷史股價三張表。
// 此檔為純 Dart（不含任何 Flutter 依賴）；正式環境的資料庫檔案位置
// 由 database_connection.dart 的 OpenConnection() 提供。

import 'package:drift/drift.dart';

import 'transaction_dao.dart';
import 'quote_cache_dao.dart';
import 'historical_price_dao.dart';
import 'dividend_dao.dart';
import 'watchlist_dao.dart';
import 'tombstone_dao.dart';

part 'app_database.g.dart';

/// 交易紀錄表；(symbol, trade_date, purchase_price, quantity, transaction_type)
/// 建 UNIQUE 索引供 INSERT OR IGNORE 去重。
/// 資料列類別命名為 StockTransactionRow，避免與領域模型 StockTransaction 衝突。
@DataClassName('StockTransactionRow')
class StockTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  IntColumn get trade_date => integer()(); // yyyyMMdd
  RealColumn get purchase_price => real()();
  RealColumn get quantity => real()();
  TextColumn get transaction_type => text()(); // BUY / SELL
  RealColumn get commission => real().nullable()();
  TextColumn get comment => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{
          symbol,
          trade_date,
          purchase_price,
          quantity,
          transaction_type,
        },
      ];
}

/// 即時報價快取表，以 symbol 為主鍵。
class QuoteCache extends Table {
  TextColumn get symbol => text()();
  RealColumn get regular_price => real().nullable()();
  IntColumn get regular_time => integer().nullable()();
  RealColumn get pre_price => real().nullable()();
  IntColumn get pre_time => integer().nullable()();
  RealColumn get post_price => real().nullable()();
  IntColumn get post_time => integer().nullable()();
  RealColumn get previous_close => real().nullable()();
  TextColumn get market_state => text().nullable()();
  IntColumn get fetched_at => integer()(); // epoch 毫秒

  @override
  Set<Column> get primaryKey => <Column>{symbol};
}

/// 歷史日收盤價表，(symbol, date) 唯一。
class HistoricalPrices extends Table {
  TextColumn get symbol => text()();
  IntColumn get date => integer()(); // yyyyMMdd
  RealColumn get close_price => real()();

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{symbol, date},
      ];
}

/// 配息事件表，(symbol, ex_date) 唯一；amount 為每股配息金額。
class DividendEvents extends Table {
  TextColumn get symbol => text()();
  IntColumn get ex_date => integer()(); // 除息日 yyyyMMdd
  RealColumn get amount_per_share => real()();

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{symbol, ex_date},
      ];
}

/// 自選股追蹤清單表，symbol 為主鍵。
class WatchlistSymbols extends Table {
  TextColumn get symbol => text()();
  TextColumn get name => text()(); // 公司/基金名稱（加入時的搜尋結果）
  IntColumn get added_at => integer()(); // 加入時間 epoch 毫秒
  TextColumn get group_name =>
      text().withDefault(const Constant('自選'))(); // 使用者自訂分類

  @override
  Set<Column> get primaryKey => <Column>{symbol};
}

/// 同步墓碑表：記錄被刪除的項目，避免雲端同步時「復活」。
/// kind = 'transaction' | 'watchlist'；item_key 為該項目的唯一鍵字串。
class SyncTombstones extends Table {
  TextColumn get kind => text()();
  TextColumn get item_key => text()();
  IntColumn get deleted_at => integer()(); // epoch 毫秒

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{kind, item_key},
      ];
}

/*
 * @author Toby
 * @date 2026/07/11
 * @class AppDatabase
 * @brief 應用程式主資料庫，聚合三張表與兩個 DAO。
 * @note 測試以 NativeDatabase.memory() 注入；正式環境用 OpenConnection() 落地檔案。
 */
@DriftDatabase(
  tables: <Type>[
    StockTransactions,
    QuoteCache,
    HistoricalPrices,
    DividendEvents,
    WatchlistSymbols,
    SyncTombstones,
  ],
  daos: <Type>[
    TransactionDao,
    QuoteCacheDao,
    HistoricalPriceDao,
    DividendDao,
    WatchlistDao,
    TombstoneDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 → v2：新增配息事件表
          if (from < 2) {
            await m.createTable(dividendEvents);
          }
          // v2 → v3：新增追蹤清單表
          if (from < 3) {
            await m.createTable(watchlistSymbols);
          }
          // v3 → v4：追蹤清單加入分類欄位
          if (from >= 3 && from < 4) {
            await m.addColumn(watchlistSymbols, watchlistSymbols.group_name);
          }
          // v4 → v5：新增同步墓碑表（雲端同步防刪除復活）
          if (from < 5) {
            await m.createTable(syncTombstones);
          }
        },
      );
}

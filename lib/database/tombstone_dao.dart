// 同步墓碑 DAO：記錄與查詢被刪除項目的唯一鍵，供雲端同步合併時排除。

import 'package:drift/drift.dart';

import '../models/stock_transaction.dart';
import 'app_database.dart';

part 'tombstone_dao.g.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/12
 *
 * @class   TombstoneDao
 *
 * @brief   封裝 sync_tombstones 表。交易的 item_key 為
 *          「symbol|trade_date|price|qty|type」，追蹤股為 symbol。
 */
@DriftAccessor(tables: <Type>[SyncTombstones])
class TombstoneDao extends DatabaseAccessor<AppDatabase>
    with _$TombstoneDaoMixin {
  static const String KIND_TRANSACTION = 'transaction';
  static const String KIND_WATCHLIST = 'watchlist';

  TombstoneDao(super.db);

  /// 由交易內容組出墓碑唯一鍵。
  static String BuildTransactionKey(StockTransaction tx) {
    return '${tx.symbol}|${tx.trade_date}|${tx.purchase_price}|'
        '${tx.quantity}|${FormatTransactionType(tx.transaction_type)}';
  }

  /// 新增墓碑（重複忽略）。
  Future<void> AddTombstone(String kind, String item_key) async {
    await into(syncTombstones).insert(
      SyncTombstonesCompanion.insert(
        kind: kind,
        item_key: item_key,
        deleted_at: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 移除墓碑（項目被重新加入時呼叫）。
  Future<void> RemoveTombstone(String kind, String item_key) async {
    await (delete(syncTombstones)
          ..where((SyncTombstones t) =>
              t.kind.equals(kind) & t.item_key.equals(item_key)))
        .go();
  }

  /// 取得全部墓碑。
  Future<List<SyncTombstone>> GetAllTombstones() {
    return select(syncTombstones).get();
  }

  /// 取得指定類型的墓碑鍵集合。
  Future<Set<String>> GetTombstoneKeys(String kind) async {
    final List<SyncTombstone> rows = await (select(syncTombstones)
          ..where((SyncTombstones t) => t.kind.equals(kind)))
        .get();
    return rows.map((SyncTombstone r) => r.item_key).toSet();
  }
}

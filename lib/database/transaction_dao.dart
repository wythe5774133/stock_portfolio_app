// 交易紀錄 DAO：負責交易表的寫入（去重）與查詢。

import 'package:drift/drift.dart';

import '../models/stock_transaction.dart' as model;
import 'app_database.dart';

part 'transaction_dao.g.dart';

/*
 * @author Toby
 * @date 2026/07/11
 * @class TransactionDao
 * @brief 封裝 stock_transactions 表的存取，提供去重寫入與依代號查詢。
 */
@DriftAccessor(tables: <Type>[StockTransactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /*
   * @fn InsertIgnoreTransaction
   * @brief 寫入單筆交易，若違反去重唯一鍵（symbol+trade_date+price+qty+type）則忽略。
   * @param transaction 欲寫入的交易模型
   * @return true 表示實際插入，false 表示因重複被忽略
   * @note 不能依賴 insertOrIgnore 的回傳 rowid 判斷是否重複——
   *       SQLite 在 ignore 時 last_insert_rowid 會殘留上一次成功插入的值，
   *       因此改為先明確查詢是否存在。
   */
  Future<bool> InsertIgnoreTransaction(model.StockTransaction transaction) async {
    final String type_text =
        model.FormatTransactionType(transaction.transaction_type);
    final List<StockTransactionRow> existing = await (select(stockTransactions)
          ..where((StockTransactions t) =>
              t.symbol.equals(transaction.symbol) &
              t.trade_date.equals(transaction.trade_date) &
              t.purchase_price.equals(transaction.purchase_price) &
              t.quantity.equals(transaction.quantity) &
              t.transaction_type.equals(type_text))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) {
      return false;
    }
    await into(stockTransactions).insert(
      StockTransactionsCompanion.insert(
        symbol: transaction.symbol,
        trade_date: transaction.trade_date,
        purchase_price: transaction.purchase_price,
        quantity: transaction.quantity,
        transaction_type: type_text,
        commission: Value<double?>(transaction.commission),
        comment: Value<String?>(transaction.comment),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return true;
  }

  /// 取得全部交易，依 symbol、trade_date、id 升冪排序。
  Future<List<model.StockTransaction>> GetAllTransactions() async {
    final List<StockTransactionRow> rows = await (select(stockTransactions)
          ..orderBy(<OrderClauseGenerator<StockTransactions>>[
            (StockTransactions t) => OrderingTerm(expression: t.symbol),
            (StockTransactions t) => OrderingTerm(expression: t.trade_date),
            (StockTransactions t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(MapRowToModel).toList();
  }

  /// 取得單一代號的交易，依 trade_date、id 升冪排序。
  Future<List<model.StockTransaction>> GetTransactionsBySymbol(
      String symbol) async {
    final List<StockTransactionRow> rows = await (select(stockTransactions)
          ..where((StockTransactions t) => t.symbol.equals(symbol))
          ..orderBy(<OrderClauseGenerator<StockTransactions>>[
            (StockTransactions t) => OrderingTerm(expression: t.trade_date),
            (StockTransactions t) => OrderingTerm(expression: t.id),
          ]))
        .get();
    return rows.map(MapRowToModel).toList();
  }

  /// 依主鍵刪除單筆交易；回傳是否有刪到。
  Future<bool> DeleteTransactionById(int id) async {
    final int deleted_count = await (delete(stockTransactions)
          ..where((StockTransactions t) => t.id.equals(id)))
        .go();
    return deleted_count > 0;
  }

  /// 將 drift 資料列轉為領域模型。
  model.StockTransaction MapRowToModel(StockTransactionRow row) {
    return model.StockTransaction(
      id: row.id,
      symbol: row.symbol,
      trade_date: row.trade_date,
      purchase_price: row.purchase_price,
      quantity: row.quantity,
      transaction_type:
          model.ParseTransactionType(row.transaction_type) ??
              model.TransactionType.buy,
      commission: row.commission,
      comment: row.comment,
    );
  }
}

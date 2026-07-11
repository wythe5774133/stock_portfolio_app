// 追蹤清單 DAO：watchlist_symbols 表的新增、移除與查詢。

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'watchlist_dao.g.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   WatchlistDao
 *
 * @brief   封裝自選股追蹤清單的存取；symbol 為主鍵，重複加入自動忽略。
 */
@DriftAccessor(tables: <Type>[WatchlistSymbols])
class WatchlistDao extends DatabaseAccessor<AppDatabase>
    with _$WatchlistDaoMixin {
  WatchlistDao(super.db);

  /// 加入追蹤；已存在則忽略。回傳 true 表示實際新增。
  Future<bool> AddSymbol(String symbol, String name, int added_at) async {
    final WatchlistSymbol? existing = await (select(watchlistSymbols)
          ..where((WatchlistSymbols t) => t.symbol.equals(symbol)))
        .getSingleOrNull();
    if (existing != null) {
      return false;
    }
    await into(watchlistSymbols).insert(
      WatchlistSymbolsCompanion.insert(
        symbol: symbol,
        name: name,
        added_at: added_at,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return true;
  }

  /// 移除追蹤。
  Future<void> RemoveSymbol(String symbol) async {
    await (delete(watchlistSymbols)
          ..where((WatchlistSymbols t) => t.symbol.equals(symbol)))
        .go();
  }

  /// 取得全部追蹤（依加入時間排序）。
  Future<List<WatchlistSymbol>> GetAllSymbols() async {
    return (select(watchlistSymbols)
          ..orderBy(<OrderClauseGenerator<WatchlistSymbols>>[
            (WatchlistSymbols t) => OrderingTerm(expression: t.added_at),
          ]))
        .get();
  }
}

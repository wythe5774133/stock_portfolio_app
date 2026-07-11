// 配息事件 DAO：dividend_events 表的批量寫入與查詢。

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'dividend_dao.g.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   DividendDao
 *
 * @brief   封裝 dividend_events 表；(symbol, ex_date) 唯一，重複寫入自動忽略。
 */
@DriftAccessor(tables: <Type>[DividendEvents])
class DividendDao extends DatabaseAccessor<AppDatabase>
    with _$DividendDaoMixin {
  DividendDao(super.db);

  /// 批量寫入單一代號的配息事件（key 為除息日 yyyyMMdd，重複忽略）。
  Future<void> SaveDividendEvents(
      String symbol, Map<int, double> amounts_by_ex_date) async {
    await batch((Batch b) {
      for (final MapEntry<int, double> entry in amounts_by_ex_date.entries) {
        b.insert(
          dividendEvents,
          DividendEventsCompanion.insert(
            symbol: symbol,
            ex_date: entry.key,
            amount_per_share: entry.value,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 讀取全部代號的配息事件，回傳 {symbol: {ex_date: 每股金額}}。
  Future<Map<String, Map<int, double>>> GetAllDividendEvents() async {
    final List<DividendEvent> rows = await select(dividendEvents).get();
    final Map<String, Map<int, double>> result = <String, Map<int, double>>{};
    for (final DividendEvent row in rows) {
      result.putIfAbsent(row.symbol, () => <int, double>{})[row.ex_date] =
          row.amount_per_share;
    }
    return result;
  }
}

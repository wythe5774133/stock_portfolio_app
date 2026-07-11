// 歷史日收盤價 DAO：負責 historical_prices 表的批量寫入與查詢。

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'historical_price_dao.g.dart';

/*
 * @author Toby
 * @date 2026/07/11
 * @class HistoricalPriceDao
 * @brief 封裝 historical_prices 表的存取；(symbol, date) 唯一，重複寫入自動忽略。
 */
@DriftAccessor(tables: <Type>[HistoricalPrices])
class HistoricalPriceDao extends DatabaseAccessor<AppDatabase>
    with _$HistoricalPriceDaoMixin {
  HistoricalPriceDao(super.db);

  /// 批量寫入單一代號的日收盤價（key 為 yyyyMMdd，重複日期忽略）。
  Future<void> SaveHistoricalCloses(
      String symbol, Map<int, double> closes_by_date) async {
    await batch((Batch b) {
      for (final MapEntry<int, double> entry in closes_by_date.entries) {
        b.insert(
          historicalPrices,
          HistoricalPricesCompanion.insert(
            symbol: symbol,
            date: entry.key,
            close_price: entry.value,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 讀取單一代號的全部日收盤價，回傳 {yyyyMMdd: close}。
  Future<Map<int, double>> GetHistoricalCloses(String symbol) async {
    final List<HistoricalPrice> rows = await (select(historicalPrices)
          ..where((HistoricalPrices t) => t.symbol.equals(symbol))
          ..orderBy(<OrderClauseGenerator<HistoricalPrices>>[
            (HistoricalPrices t) => OrderingTerm(expression: t.date),
          ]))
        .get();
    return <int, double>{
      for (final HistoricalPrice row in rows) row.date: row.close_price,
    };
  }

  /// 讀取全部代號的日收盤價，回傳 {symbol: {yyyyMMdd: close}}。
  Future<Map<String, Map<int, double>>> GetAllHistoricalCloses() async {
    final List<HistoricalPrice> rows = await select(historicalPrices).get();
    final Map<String, Map<int, double>> result = <String, Map<int, double>>{};
    for (final HistoricalPrice row in rows) {
      result.putIfAbsent(row.symbol, () => <int, double>{})[row.date] =
          row.close_price;
    }
    return result;
  }

  /// 取得單一代號快取中最新的日期（yyyyMMdd），無資料回傳 null。
  Future<int?> GetLatestCachedDate(String symbol) async {
    final HistoricalPrice? row = await (select(historicalPrices)
          ..where((HistoricalPrices t) => t.symbol.equals(symbol))
          ..orderBy(<OrderClauseGenerator<HistoricalPrices>>[
            (HistoricalPrices t) =>
                OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.date;
  }
}

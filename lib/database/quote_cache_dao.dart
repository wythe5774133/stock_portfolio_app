// 報價快取 DAO：負責 quote_cache 表的 upsert 與查詢。

import 'package:drift/drift.dart';

import '../models/stock_quote.dart';
import 'app_database.dart';

part 'quote_cache_dao.g.dart';

/*
 * @author Toby
 * @date 2026/07/11
 * @class QuoteCacheDao
 * @brief 封裝 quote_cache 表的存取，提供以 symbol 為主鍵的 upsert 與讀取。
 */
@DriftAccessor(tables: <Type>[QuoteCache])
class QuoteCacheDao extends DatabaseAccessor<AppDatabase>
    with _$QuoteCacheDaoMixin {
  QuoteCacheDao(super.db);

  /// 以 symbol 為主鍵 upsert 單筆報價快取。
  Future<void> SaveQuote(StockQuote quote) async {
    await into(quoteCache).insertOnConflictUpdate(
      QuoteCacheCompanion.insert(
        symbol: quote.symbol,
        regular_price: Value<double?>(quote.regular_price),
        regular_time: Value<int?>(quote.regular_time),
        pre_price: Value<double?>(quote.pre_price),
        pre_time: Value<int?>(quote.pre_time),
        post_price: Value<double?>(quote.post_price),
        post_time: Value<int?>(quote.post_time),
        previous_close: Value<double?>(quote.previous_close),
        market_state: Value<String?>(quote.market_state),
        fetched_at: quote.fetched_at.millisecondsSinceEpoch,
      ),
    );
  }

  /// 批量 upsert 多筆報價快取。
  Future<void> SaveQuotes(Iterable<StockQuote> quotes) async {
    await batch((Batch b) {
      b.insertAllOnConflictUpdate(
        quoteCache,
        quotes
            .map((StockQuote quote) => QuoteCacheCompanion.insert(
                  symbol: quote.symbol,
                  regular_price: Value<double?>(quote.regular_price),
                  regular_time: Value<int?>(quote.regular_time),
                  pre_price: Value<double?>(quote.pre_price),
                  pre_time: Value<int?>(quote.pre_time),
                  post_price: Value<double?>(quote.post_price),
                  post_time: Value<int?>(quote.post_time),
                  previous_close: Value<double?>(quote.previous_close),
                  market_state: Value<String?>(quote.market_state),
                  fetched_at: quote.fetched_at.millisecondsSinceEpoch,
                ))
            .toList(),
      );
    });
  }

  /// 讀取全部快取報價。
  Future<List<StockQuote>> GetAllCachedQuotes() async {
    final List<QuoteCacheData> rows = await select(quoteCache).get();
    return rows.map(MapRowToQuote).toList();
  }

  /// 將 drift 資料列轉為 StockQuote 模型。
  StockQuote MapRowToQuote(QuoteCacheData row) {
    return StockQuote(
      symbol: row.symbol,
      regular_price: row.regular_price,
      regular_time: row.regular_time,
      pre_price: row.pre_price,
      pre_time: row.pre_time,
      post_price: row.post_price,
      post_time: row.post_time,
      previous_close: row.previous_close,
      fetched_at: DateTime.fromMillisecondsSinceEpoch(row.fetched_at),
      market_state: row.market_state,
    );
  }
}

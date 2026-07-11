// 即時股價報價的純資料類別。

/*
 * @author Toby
 * @date 2026/07/11
 * @class StockQuote
 * @brief 單檔股票的即時報價快照，涵蓋盤前/盤中/盤後價格。
 * @note 各價格欄位可為 null（例如沒有盤前成交價）。
 *       時間欄位為 epoch 秒（Yahoo 原始格式），fetched_at 為本地抓取時間。
 */
class StockQuote {
  final String symbol; // 股票代號
  final double? regular_price; // 盤中價
  final int? regular_time; // 盤中價時間（epoch 秒）
  final double? pre_price; // 盤前價
  final int? pre_time; // 盤前價時間（epoch 秒）
  final double? post_price; // 盤後價
  final int? post_time; // 盤後價時間（epoch 秒）
  final double? previous_close; // 昨收
  final DateTime fetched_at; // 本地抓取時間
  final String? market_state; // Yahoo marketState（PRE/REGULAR/POST/CLOSED...）

  // 以下為個股詳情頁使用的延伸欄位（不進報價快取表）
  final double? open_price; // 今開
  final double? day_high; // 今高
  final double? day_low; // 今低
  final double? volume; // 成交量
  final double? fifty_two_week_high; // 52 週高
  final double? fifty_two_week_low; // 52 週低
  final double? market_cap; // 市值
  final double? trailing_pe; // 本益比（近四季）

  const StockQuote({
    required this.symbol,
    this.regular_price,
    this.regular_time,
    this.pre_price,
    this.pre_time,
    this.post_price,
    this.post_time,
    this.previous_close,
    required this.fetched_at,
    this.market_state,
    this.open_price,
    this.day_high,
    this.day_low,
    this.volume,
    this.fifty_two_week_high,
    this.fifty_two_week_low,
    this.market_cap,
    this.trailing_pe,
  });

  @override
  String toString() {
    return 'StockQuote($symbol, regular=$regular_price, '
        'pre=$pre_price, post=$post_price, state=$market_state)';
  }
}

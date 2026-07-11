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
  });

  @override
  String toString() {
    return 'StockQuote($symbol, regular=$regular_price, '
        'pre=$pre_price, post=$post_price, state=$market_state)';
  }
}

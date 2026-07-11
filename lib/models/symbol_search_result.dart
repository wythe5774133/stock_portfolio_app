// 股票代號搜尋的單筆結果。

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SymbolSearchResult
 *
 * @brief   Yahoo 搜尋端點回傳的單一股票：代號、名稱、交易所與類型。
 */
class SymbolSearchResult {
  final String symbol; // 股票代號（如 NVDA、2330.TW）
  final String name; // 公司/基金名稱
  final String exchange; // 交易所顯示名（如 NASDAQ、Taiwan）
  final String quote_type; // EQUITY / ETF / INDEX ...

  const SymbolSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.quote_type,
  });

  @override
  String toString() => 'SymbolSearchResult($symbol, $name, $exchange)';
}

// 市場註冊表：由股票代號判斷所屬市場、幣別與顯示標籤。純函式，無外部依賴。

/*
 * @author  Toby
 *
 * @date    2026/07/17
 *
 * @class   MarketInfo
 *
 * @brief   單一市場的靜態資訊：市場代號、報價幣別與顯示用標籤。
 *
 * @note    market_id 目前為 'us' 或 'tw'；currency 為 ISO 幣別碼（USD / TWD）。
 */
class MarketInfo {
  final String market_id; // 市場代號：'us' | 'tw'
  final String currency; // 報價幣別：'USD' | 'TWD'
  final String market_label; // 顯示標籤：'美股' | '台股'
  final String currency_symbol; // 幣別符號：r'$' | 'NT$'

  const MarketInfo({
    required this.market_id,
    required this.currency,
    required this.market_label,
    required this.currency_symbol,
  });
}

/// 1 美元兌台幣的匯率代號（Yahoo 一般 symbol，走與個股相同的報價／歷史管線）。
const String USD_TWD_FX_SYMBOL = 'TWD=X';

/// 美股市場資訊（含美股個股、指數、匯率等非台股代號）。
const MarketInfo _US_MARKET = MarketInfo(
  market_id: 'us',
  currency: 'USD',
  market_label: '美股',
  currency_symbol: '\$',
);

/// 台股市場資訊。
const MarketInfo _TW_MARKET = MarketInfo(
  market_id: 'tw',
  currency: 'TWD',
  market_label: '台股',
  currency_symbol: 'NT\$',
);

/*
 *  @fn      MarketInfo ResolveMarketForSymbol(String symbol)
 *
 *  @brief   ( 由代號後綴判斷所屬市場：.TW / .TWO 為台股，其餘為美股 )
 *
 *  @param   symbol - 股票代號（大小寫不敏感）
 *
 *  @return  對應的 MarketInfo；無台股後綴（含無後綴、^ 指數、=X 匯率）一律視為美股
 *
 *  @note    純函式，供計算引擎與 UI 共用。
 */
MarketInfo ResolveMarketForSymbol(String symbol) {
  final String upper = symbol.toUpperCase();
  if (upper.endsWith('.TW') || upper.endsWith('.TWO')) {
    return _TW_MARKET;
  }
  return _US_MARKET;
}

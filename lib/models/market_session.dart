// 美股交易時段列舉。

/*
 * @author Toby
 * @date 2026/07/11
 * @enum MarketSession
 * @brief 依美東時間判斷出的美股當前交易時段。
 * @note premarket 04:00–09:30、regular 09:30–16:00、postmarket 16:00–20:00，
 *       其餘（含週末）為 closed。
 */
enum MarketSession {
  premarket,
  regular,
  postmarket,
  closed,
}

/// 將 MarketSession 轉為易讀字串。
String FormatMarketSession(MarketSession session) {
  switch (session) {
    case MarketSession.premarket:
      return 'premarket';
    case MarketSession.regular:
      return 'regular';
    case MarketSession.postmarket:
      return 'postmarket';
    case MarketSession.closed:
      return 'closed';
  }
}

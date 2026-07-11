// K 線圖單根蠟燭的資料（開高低收＋成交量）。

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   OhlcvCandle
 *
 * @brief   單一時間單位（日/週/月）的開高低收與成交量。
 */
class OhlcvCandle {
  final int date; // 該根 K 線起始日期 yyyyMMdd
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const OhlcvCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// 收盤高於等於開盤（上漲 K）。
  bool get is_bullish => close >= open;

  @override
  String toString() =>
      'OhlcvCandle($date, o=$open h=$high l=$low c=$close v=$volume)';
}

/// K 線時間單位。
enum CandleInterval {
  daily,
  weekly,
  monthly,
}

/// K 線時間單位的顯示標籤。
String FormatCandleInterval(CandleInterval interval) {
  switch (interval) {
    case CandleInterval.daily:
      return '日K';
    case CandleInterval.weekly:
      return '週K';
    case CandleInterval.monthly:
      return '月K';
  }
}

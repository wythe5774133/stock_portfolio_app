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

/// K 線時間範圍（值為 Yahoo range 參數與顯示標籤）。
enum CandleRange {
  three_months('3mo', '3月'),
  six_months('6mo', '6月'),
  one_year('1y', '1年'),
  two_years('2y', '2年'),
  five_years('5y', '5年'),
  ten_years('10y', '10年'),
  max('max', '全部');

  final String yahoo_value; // Yahoo chart 端點的 range 參數
  final String label; // UI 顯示標籤

  const CandleRange(this.yahoo_value, this.label);
}

/// 各時間單位可選的範圍（避免日K抓十年導致資料量過大）。
List<CandleRange> GetRangesForInterval(CandleInterval interval) {
  switch (interval) {
    case CandleInterval.daily:
      return <CandleRange>[
        CandleRange.three_months,
        CandleRange.six_months,
        CandleRange.one_year,
      ];
    case CandleInterval.weekly:
      return <CandleRange>[
        CandleRange.one_year,
        CandleRange.two_years,
        CandleRange.five_years,
      ];
    case CandleInterval.monthly:
      return <CandleRange>[
        CandleRange.five_years,
        CandleRange.ten_years,
        CandleRange.max,
      ];
  }
}

/// 各時間單位的預設範圍。
CandleRange GetDefaultRangeForInterval(CandleInterval interval) {
  switch (interval) {
    case CandleInterval.daily:
      return CandleRange.six_months;
    case CandleInterval.weekly:
      return CandleRange.two_years;
    case CandleInterval.monthly:
      return CandleRange.ten_years;
  }
}

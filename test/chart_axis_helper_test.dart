// 圖表座標軸工具測試：Y 軸自動縮放的範圍與刻度、金額標籤格式、
// X 軸依期間長度在日曆邊界產生的日期標籤。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/ui/widgets/chart_axis_helper.dart';

/// 產生 from～to（含）每日的 yyyyMMdd 序列。
List<int> BuildDailyDates(DateTime from, DateTime to) {
  final List<int> dates = <int>[];
  for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
    dates.add(d.year * 10000 + d.month * 100 + d.day);
  }
  return dates;
}

/// 只取標籤文字與其日期，方便比對。
List<(int, String)> LabelDates(List<int> dates) {
  return <(int, String)>[
    for (final (int, String) label in BuildDateAxisLabels(dates))
      (dates[label.$1], label.$2),
  ];
}

void main() {
  group('CalculateNiceAxisRange', () {
    test('1 年期間：下限不從 0 開始，刻度 50K', () {
      final NiceAxisRange range = CalculateNiceAxisRange(105000, 412000);
      expect(range.min, 100000);
      expect(range.max, 450000);
      expect(range.interval, 50000);
    });

    test('全部期間：資料接近 0 時從 0 開始，刻度 100K', () {
      final NiceAxisRange range = CalculateNiceAxisRange(30000, 415000);
      expect(range.min, 0);
      expect(range.max, 500000);
      expect(range.interval, 100000);
    });

    test('貼齊刻度時上下各多留一格', () {
      final NiceAxisRange range = CalculateNiceAxisRange(200000, 400000);
      expect(range.min, lessThan(200000));
      expect(range.max, greaterThan(400000));
    });

    test('水平線不會產生零高度範圍；格數不超過上限', () {
      final NiceAxisRange flat = CalculateNiceAxisRange(100, 100);
      expect(flat.max, greaterThan(flat.min));
      for (final (double, double) data in <(double, double)>[
        (380000, 410000),
        (12.3, 18.9),
        (0, 1234567),
        (98765, 99012),
      ]) {
        final NiceAxisRange range = CalculateNiceAxisRange(data.$1, data.$2);
        expect(range.min, lessThanOrEqualTo(data.$1));
        expect(range.max, greaterThanOrEqualTo(data.$2));
        expect(((range.max - range.min) / range.interval).round(),
            lessThanOrEqualTo(7),
            reason: '$data → $range');
      }
    });
  });

  group('FormatAxisMoney', () {
    test('依量級選單位，小數位數剛好分辨刻度', () {
      const NiceAxisRange thousands =
          NiceAxisRange(min: 100000, max: 450000, interval: 50000);
      expect(FormatAxisMoney(450000, thousands, 'TWD'), 'NT\$450K');
      expect(FormatAxisMoney(0, thousands, 'TWD'), 'NT\$0K');

      const NiceAxisRange fine =
          NiceAxisRange(min: 100000, max: 103000, interval: 500);
      expect(FormatAxisMoney(100500, fine, 'USD'), '\$100.5K');

      const NiceAxisRange millions =
          NiceAxisRange(min: 1000000, max: 2000000, interval: 250000);
      expect(FormatAxisMoney(1250000, millions, 'USD'), '\$1.25M');

      const NiceAxisRange small =
          NiceAxisRange(min: 0, max: 9000, interval: 1500);
      expect(FormatAxisMoney(7500, small, 'USD'), '\$7,500');
    });
  });

  group('BuildDateAxisLabels', () {
    test('1 個月：每週一標 M/d', () {
      final List<int> dates =
          BuildDailyDates(DateTime.utc(2026, 9, 22), DateTime.utc(2026, 10, 22));
      expect(LabelDates(dates), <(int, String)>[
        (20260928, '9/28'),
        (20261005, '10/5'),
        (20261012, '10/12'),
        (20261019, '10/19'),
      ]);
    });

    test('6 個月：每月一標，1 月顯示年份', () {
      final List<int> dates =
          BuildDailyDates(DateTime.utc(2025, 10, 22), DateTime.utc(2026, 4, 22));
      expect(LabelDates(dates), <(int, String)>[
        (20251101, '11月'),
        (20251201, '12月'),
        (20260101, '2026年'),
        (20260201, '2月'),
        (20260301, '3月'),
        (20260401, '4月'),
      ]);
    });

    test('1 年：每季一標', () {
      final List<int> dates =
          BuildDailyDates(DateTime.utc(2025, 10, 22), DateTime.utc(2026, 10, 22));
      expect(LabelDates(dates), <(int, String)>[
        (20260101, '2026年'),
        (20260401, '4月'),
        (20260701, '7月'),
        (20261001, '10月'),
      ]);
    });

    test('2 年：每半年一標', () {
      final List<int> dates =
          BuildDailyDates(DateTime.utc(2024, 10, 22), DateTime.utc(2026, 10, 22));
      expect(LabelDates(dates), <(int, String)>[
        (20250101, '2025年'),
        (20250701, '7月'),
        (20260101, '2026年'),
        (20260701, '7月'),
      ]);
    });

    test('全部（4 年多）：每年一標', () {
      final List<int> dates =
          BuildDailyDates(DateTime.utc(2022, 5, 2), DateTime.utc(2026, 10, 22));
      expect(LabelDates(dates), <(int, String)>[
        (20230101, '2023年'),
        (20240101, '2024年'),
        (20250101, '2025年'),
        (20260101, '2026年'),
      ]);
    });

    test('資料不足兩筆回傳空清單', () {
      expect(BuildDateAxisLabels(<int>[20261022]), isEmpty);
    });
  });
}

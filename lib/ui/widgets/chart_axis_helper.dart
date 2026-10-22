// 圖表座標軸共用工具：Y 軸依資料範圍自動縮放並取整齊刻度、
// X 軸依時間長度在週／月／季／年等日曆邊界放日期標籤。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../money_format.dart';

/*
 * @author  Toby
 *
 * @date    2026/10/22
 *
 * @class   NiceAxisRange
 *
 * @brief   Y 軸範圍與刻度間距（min、max 皆為 interval 的整數倍）。
 */
class NiceAxisRange {
  final double min; // Y 軸下限
  final double max; // Y 軸上限
  final double interval; // 刻度間距

  const NiceAxisRange({
    required this.min,
    required this.max,
    required this.interval,
  });

  @override
  String toString() => 'NiceAxisRange($min, $max, step=$interval)';
}

/*
 *  @fn      NiceAxisRange CalculateNiceAxisRange(double data_min, double data_max,
 *               {int max_intervals, bool clamp_at_zero})
 *
 *  @brief   ( 依資料最小／最大值算出整齊的 Y 軸範圍與刻度間距 )
 *
 *  @param   data_min - 資料最小值
 *  @param   data_max - 資料最大值
 *  @param   max_intervals - 刻度格數上限（預設 7）
 *  @param   clamp_at_zero - 資料皆 ≥ 0 時下限不低於 0
 *
 *  @return  NiceAxisRange；刻度間距取 1、2、2.5、5 × 10 的次方中，
 *           格數不超過 max_intervals 的最小者
 *
 *  @note    資料貼齊上下限不到 5% 刻度時會多留一格，避免折線貼邊。
 */
NiceAxisRange CalculateNiceAxisRange(
  double data_min,
  double data_max, {
  int max_intervals = 7,
  bool clamp_at_zero = true,
}) {
  if (!data_min.isFinite || !data_max.isFinite) {
    return const NiceAxisRange(min: 0, max: 1, interval: 0.25);
  }
  if (data_min > data_max) {
    final double temp = data_min;
    data_min = data_max;
    data_max = temp;
  }
  double span = data_max - data_min;
  if (span <= 0) {
    span = data_max.abs() > 0 ? data_max.abs() * 0.1 : 1; // 水平線
  }

  const List<double> MULTIPLIERS = <double>[1, 2, 2.5, 5];
  final double rough_step = span / max_intervals;
  double magnitude =
      math.pow(10, (math.log(rough_step) / math.ln10).floor()).toDouble();

  for (int decade = 0; decade < 4; decade++) {
    for (final double multiplier in MULTIPLIERS) {
      final double step = multiplier * magnitude;
      double lower = (data_min / step).floor() * step;
      double upper = (data_max / step).ceil() * step;
      if (upper - data_max < step * 0.05) {
        upper += step;
      }
      if (data_min - lower < step * 0.05) {
        lower -= step;
      }
      if (clamp_at_zero && data_min >= 0 && lower < 0) {
        lower = 0;
      }
      if (((upper - lower) / step).round() <= max_intervals) {
        return NiceAxisRange(min: lower, max: upper, interval: step);
      }
    }
    magnitude *= 10;
  }
  return NiceAxisRange(
    min: data_min - span * 0.1,
    max: data_max + span * 0.1,
    interval: span / 4,
  );
}

/*
 *  @fn      String FormatAxisMoney(double value, NiceAxisRange range, String currency)
 *
 *  @brief   ( Y 軸金額標籤：依軸的量級選 K／M 單位，小數位數剛好能分辨各刻度 )
 *
 *  @param   value - 刻度值
 *  @param   range - 該軸的範圍與間距
 *  @param   currency - 幣別（'USD' | 'TWD'）
 *
 *  @return  例：NT$450K、$1.25M、$8,500
 */
String FormatAxisMoney(double value, NiceAxisRange range, String currency) {
  final double axis_max = math.max(range.max.abs(), range.min.abs());
  double unit = 1;
  String suffix = '';
  if (axis_max >= 1e9) {
    unit = 1e9;
    suffix = 'B';
  } else if (axis_max >= 1e6) {
    unit = 1e6;
    suffix = 'M';
  } else if (axis_max >= 1e4) {
    unit = 1e3;
    suffix = 'K';
  }

  int decimals = 0;
  final double scaled_step = range.interval / unit;
  while (decimals < 2) {
    final double shifted = scaled_step * math.pow(10, decimals);
    if ((shifted - shifted.round()).abs() < 1e-6) {
      break;
    }
    decimals++;
  }

  final String symbol = ResolveCurrencySymbol(currency);
  final String sign = value < 0 ? '-' : '';
  final double scaled = value.abs() / unit;
  final String number = unit == 1
      ? NumberFormat.decimalPatternDigits(decimalDigits: decimals)
          .format(scaled)
      : scaled.toStringAsFixed(decimals);
  return '$sign$symbol$number$suffix';
}

/*
 *  @fn      List<(int, String)> BuildDateAxisLabels(List<int> dates)
 *
 *  @brief   ( 依日期序列的時間長度，在日曆邊界產生 X 軸標籤 )
 *
 *  @param   dates - 由舊到新的 yyyyMMdd 序列
 *
 *  @return  (索引, 標籤) 清單：
 *           45 天內每週一（M/d）、200 天內每月、400 天內每季、
 *           800 天內每半年（1 月顯示「yyyy年」，其餘「M月」）、
 *           更長每年或每兩年（yyyy年）
 *
 *  @note    標籤放在跨入新區間的第一個日期，第一筆資料本身不放標籤。
 */
List<(int, String)> BuildDateAxisLabels(List<int> dates) {
  if (dates.length < 2) {
    return <(int, String)>[];
  }
  final int span_days = _ConvertToUtcDate(dates.last)
      .difference(_ConvertToUtcDate(dates.first))
      .inDays;

  int ResolveBucket(int date) {
    final int year = date ~/ 10000;
    final int month = (date ~/ 100) % 100;
    if (span_days <= 45) {
      // 以 1970/1/5（週一）為起點的週序號
      return _ConvertToUtcDate(date)
              .difference(DateTime.utc(1970, 1, 5))
              .inDays ~/
          7;
    }
    final int month_index = year * 12 + month - 1;
    if (span_days <= 200) {
      return month_index;
    }
    if (span_days <= 400) {
      return month_index ~/ 3;
    }
    if (span_days <= 800) {
      return month_index ~/ 6;
    }
    if (span_days <= 3000) {
      return year;
    }
    return year ~/ 2;
  }

  String BuildLabel(int date) {
    final int year = date ~/ 10000;
    final int month = (date ~/ 100) % 100;
    final int day = date % 100;
    if (span_days <= 45) {
      return '$month/$day';
    }
    if (span_days > 800 || month == 1) {
      return '$year年';
    }
    return '$month月';
  }

  final List<(int, String)> labels = <(int, String)>[];
  int previous_bucket = ResolveBucket(dates.first);
  for (int i = 1; i < dates.length; i++) {
    final int bucket = ResolveBucket(dates[i]);
    if (bucket != previous_bucket) {
      labels.add((i, BuildLabel(dates[i])));
      previous_bucket = bucket;
    }
  }
  return labels;
}

/// yyyyMMdd 轉 UTC 日期。
DateTime _ConvertToUtcDate(int yyyymmdd) {
  return DateTime.utc(
      yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100);
}

/*
 * @author  Toby
 *
 * @date    2026/10/22
 *
 * @class   DateAxisLabelRow
 *
 * @brief   折線圖下方的日期標籤列：依 BuildDateAxisLabels 的索引對齊到圖表的 X 位置。
 *
 * @note    left_reserved 必須等於圖表左側 Y 軸標籤的 reservedSize，
 *          且圖表右側不保留空間，標籤才會對齊資料點。
 */
class DateAxisLabelRow extends StatelessWidget {
  static const double LABEL_WIDTH = 64; // 單一標籤寬度（置中於資料點）

  final List<int> dates; // 與圖表 X 索引一一對應的 yyyyMMdd 序列
  final double left_reserved; // 圖表左側 Y 軸標籤保留寬度

  const DateAxisLabelRow({
    super.key,
    required this.dates,
    required this.left_reserved,
  });

  @override
  Widget build(BuildContext context) {
    final List<(int, String)> labels = BuildDateAxisLabels(dates);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double total_width = constraints.maxWidth;
        final double plot_width = total_width - left_reserved;
        final double max_left = math.max(0.0, total_width - LABEL_WIDTH);
        return SizedBox(
          height: 22,
          child: Stack(
            children: <Widget>[
              for (final (int, String) label in labels)
                Positioned(
                  top: 6,
                  width: LABEL_WIDTH,
                  left: math.min(
                    max_left,
                    math.max(
                      0.0,
                      left_reserved +
                          plot_width * label.$1 / (dates.length - 1) -
                          LABEL_WIDTH / 2,
                    ),
                  ),
                  child: Text(
                    label.$2,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// 漲跌配色方案：美股慣例（漲綠跌紅）與台股慣例（漲紅跌綠）可切換。

import 'package:flutter/material.dart';

/// 漲跌顏色慣例。
enum ProfitColorConvention {
  us, // 美股慣例：漲綠跌紅
  taiwan, // 台股慣例：漲紅跌綠
}

/// 將慣例轉為儲存字串。
String FormatProfitColorConvention(ProfitColorConvention convention) {
  return convention == ProfitColorConvention.us ? 'us' : 'taiwan';
}

/// 由儲存字串還原慣例，無法解析時回傳美股慣例。
ProfitColorConvention ParseProfitColorConvention(String? raw) {
  return raw == 'taiwan'
      ? ProfitColorConvention.taiwan
      : ProfitColorConvention.us;
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   ProfitColorScheme
 *
 * @brief   依目前慣例回傳獲利/虧損顏色，UI 一律透過此類別取色。
 */
class ProfitColorScheme {
  static const Color GREEN = Color(0xFF16A34A);
  static const Color RED = Color(0xFFDC2626);

  final ProfitColorConvention convention;

  const ProfitColorScheme(this.convention);

  /// 獲利（上漲）顏色。
  Color get gain_color =>
      convention == ProfitColorConvention.us ? GREEN : RED;

  /// 虧損（下跌）顏色。
  Color get loss_color =>
      convention == ProfitColorConvention.us ? RED : GREEN;

  /// 依數值正負取色（0 視為獲利色）。
  Color ResolveColorForValue(double value) {
    return value >= 0 ? gain_color : loss_color;
  }
}

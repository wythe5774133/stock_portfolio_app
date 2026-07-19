// 漲跌幅色塊標籤：圓角矩形底色為漲跌解析色、白字，自選與持倉共用。

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/19
 *
 * @class   ChangePercentBadge
 *
 * @brief   顯示漲跌百分比的小色塊：背景為傳入的漲跌解析色、文字白色粗體，
 *          如「+1.76%」「-2.21%」；percent 為 null 時顯示灰底「—」佔位。
 *
 * @note    背景色一律由呼叫端經 profit_colors.ResolveColorForValue 決定，
 *          此元件不判斷漲跌方向、不寫死紅綠。
 */
class ChangePercentBadge extends StatelessWidget {
  final double? percent;
  final Color color;
  final double font_size;

  const ChangePercentBadge({
    super.key,
    required this.percent,
    required this.color,
    this.font_size = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    final bool has_value = percent != null;
    final String label = has_value
        ? '${percent! >= 0 ? '+' : ''}${percent!.toStringAsFixed(2)}%'
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: has_value ? color : colors.subtle_background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: font_size,
          fontWeight: FontWeight.w700,
          color: has_value ? Colors.white : colors.text_muted,
        ),
      ),
    );
  }
}

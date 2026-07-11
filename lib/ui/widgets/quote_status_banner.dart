// 報價狀態列：目前時段標示、最後更新時間、報價異常提示。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/market_session.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   QuoteStatusBanner
 *
 * @brief   顯示目前美股時段（含顏色圓點）、資料最後更新時間與異常提示，
 *          讓使用者清楚知道報價的時效性。
 */
class QuoteStatusBanner extends StatelessWidget {
  final MarketSession session;
  final DateTime? last_updated_at;
  final bool is_quote_unavailable;

  const QuoteStatusBanner({
    super.key,
    required this.session,
    required this.last_updated_at,
    required this.is_quote_unavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _BuildSessionChip(),
        if (last_updated_at != null)
          Tooltip(
            message: DateFormat('yyyy/MM/dd HH:mm:ss').format(last_updated_at!),
            child: Text(
              '最後更新於 ${FormatRelativeTime(last_updated_at!)}',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ),
        if (is_quote_unavailable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              '報價暫時無法取得，顯示快取資料',
              style: TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
            ),
          ),
      ],
    );
  }

  /// 時段膠囊標籤（顏色圓點 + 名稱）。
  Widget _BuildSessionChip() {
    final (Color, String) style = ResolveSessionStyle(session);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.$1.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: style.$1, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            style.$2,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: style.$1,
            ),
          ),
        ],
      ),
    );
  }

  /// 各時段的顏色與中文名稱。
  static (Color, String) ResolveSessionStyle(MarketSession session) {
    switch (session) {
      case MarketSession.premarket:
        return (const Color(0xFFD97706), '盤前交易');
      case MarketSession.regular:
        return (const Color(0xFF16A34A), '盤中交易');
      case MarketSession.postmarket:
        return (const Color(0xFF4F6DF5), '盤後交易');
      case MarketSession.closed:
        return (const Color(0xFF6B7280), '休市');
    }
  }

  /// 相對時間文字（剛剛 / X 分鐘前 / X 小時前 / 日期）。
  static String FormatRelativeTime(DateTime time) {
    final Duration elapsed = DateTime.now().difference(time);
    if (elapsed.inSeconds < 60) {
      return '剛剛';
    }
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} 分鐘前';
    }
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours} 小時前';
    }
    return DateFormat('yyyy/MM/dd HH:mm').format(time);
  }
}

// 財報行事曆事件的純資料類別：美股財報公布、台股月營收／季報／年報法定期限。

/// 財報公布時段（美股以美東時間判斷）。
enum EarningsTiming {
  before_open, // 盤前
  during_market, // 盤中
  after_close, // 盤後
  unknown, // 時間未定
}

/// 事件種類。
enum EarningsEventKind {
  us_earnings, // 美股財報公布日（Yahoo 提供）
  tw_monthly_revenue, // 台股月營收法定期限（每月 10 日）
  tw_quarterly_report, // 台股季報法定期限（5/15、8/14、11/14）
  tw_annual_report, // 台股年報法定期限（3/31）
}

/*
 * @author  Toby
 *
 * @date    2026/09/30
 *
 * @class   EarningsEvent
 *
 * @brief   單一財報相關事件：代號、日期、時段與是否為預估／法定期限。
 *
 * @note    event_date 為 yyyyMMdd：美股為美東日期、台股為台北日期。
 *          event_time_utc 僅在美股且時段確定時有值，其餘為全天事件。
 */
class EarningsEvent {
  final String symbol; // 股票代號
  final EarningsEventKind kind; // 事件種類
  final int event_date; // 事件日期 yyyyMMdd（美股：美東；台股：台北）
  final int? end_date; // 預估區間的結束日 yyyyMMdd（無區間為 null）
  final DateTime? event_time_utc; // 確切公布時間（UTC）；全天事件為 null
  final bool is_estimate; // Yahoo 標示為預估日期
  final EarningsTiming timing; // 公布時段
  final String label; // 顯示名稱（財報、8月營收、Q2 財報、年報）

  const EarningsEvent({
    required this.symbol,
    required this.kind,
    required this.event_date,
    this.end_date,
    this.event_time_utc,
    this.is_estimate = false,
    this.timing = EarningsTiming.unknown,
    required this.label,
  });

  /// 是否為台股法定期限（實際公布可能更早）。
  bool get is_deadline => kind != EarningsEventKind.us_earnings;

  /// 排序鍵：有確切時間用時間，否則用日期當天 00:00（UTC）。
  DateTime get sort_key =>
      event_time_utc ??
      DateTime.utc(event_date ~/ 10000, (event_date ~/ 100) % 100,
          event_date % 100);

  /// 轉為快取用 JSON（僅美股財報需要快取）。
  Map<String, dynamic> ToJson() {
    return <String, dynamic>{
      'symbol': symbol,
      'kind': kind.name,
      'event_date': event_date,
      'end_date': end_date,
      'event_time_utc': event_time_utc?.millisecondsSinceEpoch,
      'is_estimate': is_estimate,
      'timing': timing.name,
      'label': label,
    };
  }

  /// 由快取 JSON 還原；格式不符回傳 null。
  static EarningsEvent? FromJson(Map<String, dynamic> json) {
    final Object? symbol = json['symbol'];
    final Object? event_date = json['event_date'];
    final EarningsEventKind? kind = _ParseEnumByName(
        EarningsEventKind.values, json['kind'] as String?);
    if (symbol is! String || event_date is! int || kind == null) {
      return null;
    }
    final Object? time_ms = json['event_time_utc'];
    return EarningsEvent(
      symbol: symbol,
      kind: kind,
      event_date: event_date,
      end_date: json['end_date'] as int?,
      event_time_utc: time_ms is int
          ? DateTime.fromMillisecondsSinceEpoch(time_ms, isUtc: true)
          : null,
      is_estimate: (json['is_estimate'] as bool?) ?? false,
      timing: _ParseEnumByName(
              EarningsTiming.values, json['timing'] as String?) ??
          EarningsTiming.unknown,
      label: (json['label'] as String?) ?? '財報',
    );
  }

  /// 依 enum 名稱查找值，找不到回傳 null。
  static T? _ParseEnumByName<T extends Enum>(List<T> values, String? name) {
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'EarningsEvent($symbol, ${kind.name}, $event_date, '
        'timing=${timing.name}, estimate=$is_estimate)';
  }
}

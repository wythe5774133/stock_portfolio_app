// 財報行事曆服務：解析 Yahoo 美股財報日期、產生台股法定公布期限、
// 篩選近期事件並輸出 .ics 行事曆檔。解析與產生皆為純函式，方便單元測試。

import 'dart:convert';

import '../logic/market_registry.dart';
import '../models/earnings_event.dart';
import 'market_session_resolver.dart';
import 'yahoo_quote_service.dart';

/*
 * @author  Toby
 *
 * @date    2026/09/30
 *
 * @class   EarningsCalendarService
 *
 * @brief   取得並整理持股／自選股的財報相關事件。
 *
 * @note    美股財報日期來自 Yahoo v7 報價的 earningsTimestamp 系列欄位；
 *          台股沒有公布日資料，改列法定最晚期限：月營收每月 10 日、
 *          Q1 5/15、Q2 8/14、Q3 11/14、年報 3/31。台股 ETF（代號 00 開頭）不列。
 */
class EarningsCalendarService {
  static const List<String> WEEKDAY_NAMES = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  final YahooQuoteService quote_service;

  EarningsCalendarService({required this.quote_service});

  /*
   *  @fn      Future<Map<String, EarningsEvent>?> FetchUsEarningsEvents(List<String> symbols, DateTime now)
   *
   *  @brief   ( 抓取美股代號的下次財報日期 )
   *
   *  @param   symbols - 美股代號清單（台股、指數、匯率由呼叫端先排除）
   *  @param   now - 目前時間（過濾已過去的財報日）
   *
   *  @return  {symbol: 事件}，沒有未來財報日的代號不在結果中；請求失敗回傳 null
   */
  Future<Map<String, EarningsEvent>?> FetchUsEarningsEvents(
    List<String> symbols,
    DateTime now,
  ) async {
    if (symbols.isEmpty) {
      return <String, EarningsEvent>{};
    }
    final List<Map<String, dynamic>>? results =
        await quote_service.FetchEarningsQuoteResults(symbols);
    if (results == null) {
      return null;
    }
    final Map<String, EarningsEvent> events = <String, EarningsEvent>{};
    for (final Map<String, dynamic> raw in results) {
      final EarningsEvent? event = ParseEarningsFromV7QuoteJson(raw, now);
      if (event != null && symbols.contains(event.symbol)) {
        events[event.symbol] = event;
      }
    }
    return events;
  }

  /// 是否需要查詢 Yahoo 財報日期（排除台股、指數 ^ 與匯率 =X）。
  static bool IsUsEarningsSymbol(String symbol) {
    if (symbol.startsWith('^') || symbol.contains('=')) {
      return false;
    }
    return ResolveMarketForSymbol(symbol).market_id == 'us';
  }

  /// 台股 ETF 判斷：代號（去掉 .TW/.TWO）以 00 開頭。
  static bool IsTaiwanEtfSymbol(String symbol) {
    return symbol.split('.').first.startsWith('00');
  }

  /*
   *  @fn      static EarningsEvent? ParseEarningsFromV7QuoteJson(Map<String, dynamic> json, DateTime now)
   *
   *  @brief   ( 從 v7 報價單檔 JSON 解析下次財報事件 )
   *
   *  @param   json - quoteResponse.result[] 的單一元素
   *  @param   now - 目前時間（美東日期早於今天的財報視為已過去）
   *
   *  @return  EarningsEvent；無財報欄位或已過去回傳 null
   *
   *  @note    讀取 earningsTimestampStart／End（區間）與 earningsTimestamp，
   *           isEarningsDateEstimate 或區間跨日時標為預估、時段未定。
   *           時間剛好是 UTC 00:00 視為只有日期（Yahoo 的日期佔位值）。
   */
  static EarningsEvent? ParseEarningsFromV7QuoteJson(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final Object? symbol = json['symbol'];
    if (symbol is! String || symbol.isEmpty) {
      return null;
    }
    final int? start_seconds = _ReadInt(json['earningsTimestampStart']) ??
        _ReadInt(json['earningsTimestamp']);
    if (start_seconds == null || start_seconds <= 0) {
      return null;
    }
    final int? end_seconds = _ReadInt(json['earningsTimestampEnd']);
    final DateTime start_utc =
        DateTime.fromMillisecondsSinceEpoch(start_seconds * 1000, isUtc: true);
    final bool is_date_only = start_utc.hour == 0 &&
        start_utc.minute == 0 &&
        start_utc.second == 0;

    final int event_date = is_date_only
        ? ConvertDateTimeToYyyymmdd(start_utc)
        : ConvertDateTimeToYyyymmdd(
            MarketSessionResolver.ConvertToNewYorkTime(start_utc));

    int? end_date;
    if (end_seconds != null && end_seconds > start_seconds) {
      final DateTime end_utc =
          DateTime.fromMillisecondsSinceEpoch(end_seconds * 1000, isUtc: true);
      final int candidate = ConvertDateTimeToYyyymmdd(
          MarketSessionResolver.ConvertToNewYorkTime(end_utc));
      if (candidate > event_date) {
        end_date = candidate;
      }
    }

    final bool is_estimate =
        json['isEarningsDateEstimate'] == true || end_date != null;
    final EarningsTiming timing = (is_estimate || is_date_only)
        ? EarningsTiming.unknown
        : ResolveEarningsTiming(start_utc);

    final int today_new_york = ConvertDateTimeToYyyymmdd(
        MarketSessionResolver.ConvertToNewYorkTime(now));
    if ((end_date ?? event_date) < today_new_york) {
      return null; // 已公布過的上一季財報
    }

    return EarningsEvent(
      symbol: symbol,
      kind: EarningsEventKind.us_earnings,
      event_date: event_date,
      end_date: end_date,
      event_time_utc: timing == EarningsTiming.unknown ? null : start_utc,
      is_estimate: is_estimate,
      timing: timing,
      label: '財報',
    );
  }

  /// 依美東時間判斷公布時段：09:30 前盤前、16:00 前盤中、之後盤後。
  static EarningsTiming ResolveEarningsTiming(DateTime moment) {
    final DateTime new_york = MarketSessionResolver.ConvertToNewYorkTime(moment);
    final int minutes_of_day = new_york.hour * 60 + new_york.minute;
    if (minutes_of_day == 0) {
      return EarningsTiming.unknown;
    }
    if (minutes_of_day < 9 * 60 + 30) {
      return EarningsTiming.before_open;
    }
    if (minutes_of_day < 16 * 60) {
      return EarningsTiming.during_market;
    }
    return EarningsTiming.after_close;
  }

  /*
   *  @fn      static List<EarningsEvent> BuildTaiwanStatutoryEvents(String symbol, int from_date, int to_date)
   *
   *  @brief   ( 產生台股在指定期間內的法定公布期限事件 )
   *
   *  @param   symbol - 台股代號（如 2330.TW）
   *  @param   from_date - 起日 yyyyMMdd（含）
   *  @param   to_date - 迄日 yyyyMMdd（含）
   *
   *  @return  依日期排序的事件；ETF 回傳空清單
   *
   *  @note    期限遇假日順延的情況不處理，一律顯示法定日期。
   */
  static List<EarningsEvent> BuildTaiwanStatutoryEvents(
    String symbol,
    int from_date,
    int to_date,
  ) {
    if (IsTaiwanEtfSymbol(symbol) || from_date > to_date) {
      return <EarningsEvent>[];
    }
    final List<EarningsEvent> events = <EarningsEvent>[];
    int year = from_date ~/ 10000;
    int month = (from_date ~/ 100) % 100;
    final int last_month_key = (to_date ~/ 10000) * 100 + (to_date ~/ 100) % 100;

    while (year * 100 + month <= last_month_key) {
      final int previous_month = month == 1 ? 12 : month - 1;
      final List<EarningsEvent> candidates = <EarningsEvent>[
        EarningsEvent(
          symbol: symbol,
          kind: EarningsEventKind.tw_monthly_revenue,
          event_date: year * 10000 + month * 100 + 10,
          label: '$previous_month月營收',
        ),
        if (month == 3)
          EarningsEvent(
            symbol: symbol,
            kind: EarningsEventKind.tw_annual_report,
            event_date: year * 10000 + 331,
            label: '${year - 1} 年報',
          ),
        if (month == 5)
          EarningsEvent(
            symbol: symbol,
            kind: EarningsEventKind.tw_quarterly_report,
            event_date: year * 10000 + 515,
            label: 'Q1 財報',
          ),
        if (month == 8)
          EarningsEvent(
            symbol: symbol,
            kind: EarningsEventKind.tw_quarterly_report,
            event_date: year * 10000 + 814,
            label: 'Q2 財報',
          ),
        if (month == 11)
          EarningsEvent(
            symbol: symbol,
            kind: EarningsEventKind.tw_quarterly_report,
            event_date: year * 10000 + 1114,
            label: 'Q3 財報',
          ),
      ];
      for (final EarningsEvent event in candidates) {
        if (event.event_date >= from_date && event.event_date <= to_date) {
          events.add(event);
        }
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    events.sort((EarningsEvent a, EarningsEvent b) =>
        a.event_date.compareTo(b.event_date));
    return events;
  }

  /*
   *  @fn      static List<EarningsEvent> SelectUpcomingEvents(List<String> symbols,
   *               Map<String, EarningsEvent> us_events, int today_date, int horizon_days)
   *
   *  @brief   ( 彙整指定代號在未來 horizon_days 天內的財報事件 )
   *
   *  @param   symbols - 追蹤中的代號（持股＋自選）
   *  @param   us_events - 美股財報快取 {symbol: 事件}
   *  @param   today_date - 今天（台北日期）yyyyMMdd
   *  @param   horizon_days - 往後涵蓋的天數（含今天）
   *
   *  @return  依時間排序的事件清單
   *
   *  @note    美股以台灣時間的顯示日期判斷；預估區間與期間有重疊即列入。
   */
  static List<EarningsEvent> SelectUpcomingEvents(
    List<String> symbols,
    Map<String, EarningsEvent> us_events,
    int today_date,
    int horizon_days,
  ) {
    final int last_date = AddDaysToYyyymmdd(today_date, horizon_days);
    final List<EarningsEvent> events = <EarningsEvent>[];
    for (final String symbol in symbols.toSet()) {
      if (ResolveMarketForSymbol(symbol).market_id == 'tw') {
        events.addAll(BuildTaiwanStatutoryEvents(symbol, today_date, last_date));
        continue;
      }
      final EarningsEvent? event = us_events[symbol];
      if (event == null) {
        continue;
      }
      final int start = ResolveTaipeiDisplayDate(event);
      final int end = event.end_date ?? start;
      if (end >= today_date && start <= last_date) {
        events.add(event);
      }
    }
    events.sort((EarningsEvent a, EarningsEvent b) {
      final int by_time = a.sort_key.compareTo(b.sort_key);
      return by_time != 0 ? by_time : a.symbol.compareTo(b.symbol);
    });
    return events;
  }

  /*
   *  @fn      static EarningsEvent? FindNextEventForSymbol(String symbol,
   *               Map<String, EarningsEvent> us_events, int today_date)
   *
   *  @brief   ( 取單一代號的下一個財報事件，供個股詳情與列表標籤使用 )
   *
   *  @return  最近的事件；沒有資料回傳 null
   */
  static EarningsEvent? FindNextEventForSymbol(
    String symbol,
    Map<String, EarningsEvent> us_events,
    int today_date,
  ) {
    if (ResolveMarketForSymbol(symbol).market_id == 'tw') {
      final List<EarningsEvent> events = BuildTaiwanStatutoryEvents(
          symbol, today_date, AddDaysToYyyymmdd(today_date, 62));
      return events.isEmpty ? null : events.first;
    }
    final EarningsEvent? event = us_events[symbol];
    if (event == null) {
      return null;
    }
    final int end = event.end_date ?? ResolveTaipeiDisplayDate(event);
    return end >= today_date ? event : null;
  }

  /// 使用者看到的日期：有確切時間轉台北日期，否則用事件日期。
  static int ResolveTaipeiDisplayDate(EarningsEvent event) {
    if (event.event_time_utc == null) {
      return event.event_date;
    }
    return ConvertDateTimeToYyyymmdd(
        MarketSessionResolver.ConvertToTaipeiTime(event.event_time_utc!));
  }

  /// 距今天數（台北日期）；預估區間已開始時回傳 0。
  static int CalculateDaysUntil(EarningsEvent event, int today_date) {
    final int days =
        DiffDaysBetween(today_date, ResolveTaipeiDisplayDate(event));
    return days < 0 ? 0 : days;
  }

  /// 距今天數的簡短文字：今天／明天／N 天後。
  static String FormatDaysUntilText(int days) {
    if (days <= 0) {
      return '今天';
    }
    if (days == 1) {
      return '明天';
    }
    return '$days 天後';
  }

  /// 時段中文名稱。
  static String FormatTimingText(EarningsTiming timing) {
    switch (timing) {
      case EarningsTiming.before_open:
        return '盤前';
      case EarningsTiming.during_market:
        return '盤中';
      case EarningsTiming.after_close:
        return '盤後';
      case EarningsTiming.unknown:
        return '時間未定';
    }
  }

  /*
   *  @fn      static String FormatEventWhenText(EarningsEvent event)
   *
   *  @brief   ( 事件時間的顯示文字 )
   *
   *  @return  例：「台灣時間 11/20（四）05:20・盤後」「預估 美東 10/28～11/3」
   *           「最晚 10/10（五）」
   */
  static String FormatEventWhenText(EarningsEvent event) {
    if (event.is_deadline) {
      return '最晚 ${FormatMonthDayWithWeekday(event.event_date)}';
    }
    if (event.event_time_utc != null) {
      final DateTime taipei =
          MarketSessionResolver.ConvertToTaipeiTime(event.event_time_utc!);
      final String hh = taipei.hour.toString().padLeft(2, '0');
      final String mm = taipei.minute.toString().padLeft(2, '0');
      return '台灣時間 '
          '${FormatMonthDayWithWeekday(ConvertDateTimeToYyyymmdd(taipei))} '
          '$hh:$mm・${FormatTimingText(event.timing)}';
    }
    if (event.end_date != null) {
      return '預估 美東 ${FormatMonthDay(event.event_date)}'
          '～${FormatMonthDay(event.end_date!)}';
    }
    final String prefix = event.is_estimate ? '預估 美東' : '美東';
    return '$prefix ${FormatMonthDayWithWeekday(event.event_date)}・時間未定';
  }

  /*
   *  @fn      static String BuildEarningsIcs(List<EarningsEvent> events, DateTime now)
   *
   *  @brief   ( 將事件輸出為 iCalendar（.ics）文字，含前一天的提醒 )
   *
   *  @param   events - 欲匯出的事件
   *  @param   now - 產生時間（DTSTAMP）
   *
   *  @return  以 CRLF 分行的 .ics 內容
   *
   *  @note    有確切時間的事件為 1 小時的定時事件，提醒在 12 小時前；
   *           其餘為全天事件，提醒在前一天 09:00。UID 由代號＋種類＋日期組成，
   *           重複匯入同一事件會更新而不是新增。
   */
  static String BuildEarningsIcs(List<EarningsEvent> events, DateTime now) {
    final List<String> lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//stock_portfolio_app//earnings//ZH-TW',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:財報行事曆',
    ];
    final String stamp = _FormatIcsUtcDateTime(now.toUtc());
    for (final EarningsEvent event in events) {
      final String summary = _BuildIcsSummary(event);
      lines.addAll(<String>[
        'BEGIN:VEVENT',
        'UID:${event.symbol}-${event.kind.name}-${event.event_date}'
            '@stock-portfolio-app',
        'DTSTAMP:$stamp',
      ]);
      if (event.event_time_utc != null) {
        lines.addAll(<String>[
          'DTSTART:${_FormatIcsUtcDateTime(event.event_time_utc!)}',
          'DTEND:${_FormatIcsUtcDateTime(event.event_time_utc!.add(const Duration(hours: 1)))}',
        ]);
      } else {
        lines.addAll(<String>[
          'DTSTART;VALUE=DATE:${event.event_date}',
          'DTEND;VALUE=DATE:'
              '${AddDaysToYyyymmdd(event.end_date ?? event.event_date, 1)}',
        ]);
      }
      lines.addAll(<String>[
        'SUMMARY:${_EscapeIcsText(summary)}',
        'DESCRIPTION:${_EscapeIcsText(_BuildIcsDescription(event))}',
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:${_EscapeIcsText(summary)}',
        event.event_time_utc != null ? 'TRIGGER:-PT12H' : 'TRIGGER:-PT15H',
        'END:VALARM',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    return '${lines.map(_FoldIcsLine).join('\r\n')}\r\n';
  }

  /// 行事曆標題，例：「NVDA 財報（盤後）」「2330.TW 9月營收（法定期限）」。
  static String _BuildIcsSummary(EarningsEvent event) {
    if (event.is_deadline) {
      return '${event.symbol} ${event.label}（法定期限）';
    }
    if (event.is_estimate) {
      return '${event.symbol} ${event.label}（預估）';
    }
    return '${event.symbol} ${event.label}'
        '（${FormatTimingText(event.timing)}）';
  }

  /// 行事曆備註。
  static String _BuildIcsDescription(EarningsEvent event) {
    if (event.is_deadline) {
      return '法定最晚公布日，公司可能提前公布；遇假日可能順延。';
    }
    if (event.is_estimate) {
      return '${FormatEventWhenText(event)}。Yahoo 預估日期，公司正式宣布後可能變動。';
    }
    return FormatEventWhenText(event);
  }

  /// iCalendar 文字跳脫：反斜線、分號、逗號與換行。
  static String _EscapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  /// UTC 時間格式化為 yyyyMMddTHHmmssZ。
  static String _FormatIcsUtcDateTime(DateTime utc) {
    String Pad2(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${Pad2(utc.month)}${Pad2(utc.day)}'
        'T${Pad2(utc.hour)}${Pad2(utc.minute)}${Pad2(utc.second)}Z';
  }

  /*
   *  警告：iCalendar 規定每行最多 75 個位元組（UTF-8），超過要折行，
   *  續行以一個空白開頭。中文一字 3 位元組，必須以位元組計算且不能切斷字元。
   */
  static String _FoldIcsLine(String line) {
    const int MAX_OCTETS = 75;
    if (utf8.encode(line).length <= MAX_OCTETS) {
      return line;
    }
    final List<String> segments = <String>[];
    final StringBuffer current = StringBuffer();
    int current_octets = 0;
    int limit = MAX_OCTETS;
    for (final int rune in line.runes) {
      final String char = String.fromCharCode(rune);
      final int octets = utf8.encode(char).length;
      if (current_octets + octets > limit) {
        segments.add(current.toString());
        current.clear();
        current_octets = 0;
        limit = MAX_OCTETS - 1; // 續行開頭的空白佔 1 位元組
      }
      current.write(char);
      current_octets += octets;
    }
    segments.add(current.toString());
    return segments.join('\r\n ');
  }

  /// 月/日（例：10/28）。
  static String FormatMonthDay(int yyyymmdd) {
    return '${(yyyymmdd ~/ 100) % 100}/${yyyymmdd % 100}';
  }

  /// 月/日（週）（例：10/28（二））。
  static String FormatMonthDayWithWeekday(int yyyymmdd) {
    final DateTime date = DateTime.utc(
        yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100);
    return '${FormatMonthDay(yyyymmdd)}（${WEEKDAY_NAMES[date.weekday - 1]}）';
  }

  /// DateTime（取其年月日欄位）轉 yyyyMMdd。
  static int ConvertDateTimeToYyyymmdd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  /// yyyyMMdd 加減天數。
  static int AddDaysToYyyymmdd(int yyyymmdd, int days) {
    final DateTime date = DateTime.utc(
        yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100 + days);
    return ConvertDateTimeToYyyymmdd(date);
  }

  /// 兩個 yyyyMMdd 相差天數（to − from）。
  static int DiffDaysBetween(int from_date, int to_date) {
    final DateTime from = DateTime.utc(
        from_date ~/ 10000, (from_date ~/ 100) % 100, from_date % 100);
    final DateTime to =
        DateTime.utc(to_date ~/ 10000, (to_date ~/ 100) % 100, to_date % 100);
    return to.difference(from).inDays;
  }

  /// JSON 數值容錯讀取為 int。
  static int? _ReadInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

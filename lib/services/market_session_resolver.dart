// 美股交易時段判斷：以美東時間（America/New_York）為準，自動處理日光節約。

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/market_session.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   MarketSessionResolver
 *
 * @brief   將任意時間點換算為美東時間並判斷所屬交易時段。
 *
 * @note    盤前 04:00–09:30、盤中 09:30–16:00、盤後 16:00–20:00（ET），
 *          其餘時間與週末為休市。美股國定假日不特別處理，
 *          該日 Yahoo 無新報價，僅會多發幾次無害的請求。
 */
class MarketSessionResolver {
  static bool _timezone_initialized = false;
  static late tz.Location _new_york;

  /// 初始化 IANA 時區資料庫（整個 App 生命週期呼叫一次即可，重複呼叫無害）。
  static void InitializeTimeZoneDatabase() {
    if (_timezone_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    _new_york = tz.getLocation('America/New_York');
    _timezone_initialized = true;
  }

  /*
   *  @fn      MarketSession ResolveMarketSessionAt(DateTime moment)
   *
   *  @brief   ( 判斷指定時間點屬於哪個美股交易時段 )
   *
   *  @param   moment - 任意時區的時間點（內部先轉 UTC 再轉美東）
   *
   *  @return  MarketSession - premarket / regular / postmarket / closed
   *
   *  @note    需先呼叫 InitializeTimeZoneDatabase()。
   */
  MarketSession ResolveMarketSessionAt(DateTime moment) {
    InitializeTimeZoneDatabase();
    final tz.TZDateTime new_york_time =
        tz.TZDateTime.from(moment.toUtc(), _new_york);

    if (new_york_time.weekday == DateTime.saturday ||
        new_york_time.weekday == DateTime.sunday) {
      return MarketSession.closed;
    }

    final int minutes_of_day = new_york_time.hour * 60 + new_york_time.minute;
    const int PREMARKET_START = 4 * 60; // 04:00
    const int REGULAR_START = 9 * 60 + 30; // 09:30
    const int REGULAR_END = 16 * 60; // 16:00
    const int POSTMARKET_END = 20 * 60; // 20:00

    if (minutes_of_day >= PREMARKET_START && minutes_of_day < REGULAR_START) {
      return MarketSession.premarket;
    }
    if (minutes_of_day >= REGULAR_START && minutes_of_day < REGULAR_END) {
      return MarketSession.regular;
    }
    if (minutes_of_day >= REGULAR_END && minutes_of_day < POSTMARKET_END) {
      return MarketSession.postmarket;
    }
    return MarketSession.closed;
  }

  /// 判斷「現在」屬於哪個美股交易時段。
  MarketSession ResolveCurrentMarketSession() {
    return ResolveMarketSessionAt(DateTime.now());
  }
}

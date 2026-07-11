// 背景報價輪詢排程器：依美股時段動態調整輪詢頻率，
// 抓到的報價寫入快取並通知 UI 監聽者。純 Dart + Timer，不依賴 widget。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/quote_cache_dao.dart';
import '../models/market_session.dart';
import '../models/stock_quote.dart';
import 'market_session_resolver.dart';
import 'yahoo_quote_service.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   QuotePollingScheduler
 *
 * @brief   背景輪詢即時報價：盤中 45 秒、盤前/盤後 3 分鐘、
 *          休市時停止抓取（僅每 10 分鐘醒來檢查時段是否改變）。
 *
 * @note    以 ChangeNotifier 通知 UI；latest_quotes 為記憶體中最新報價，
 *          啟動時會先從資料庫快取載入，離線也能顯示最後更新時間。
 */
class QuotePollingScheduler extends ChangeNotifier {
  static const Duration REGULAR_POLL_INTERVAL = Duration(seconds: 45);
  static const Duration EXTENDED_POLL_INTERVAL = Duration(minutes: 3);
  static const Duration CLOSED_CHECK_INTERVAL = Duration(minutes: 10);

  final YahooQuoteService quote_service;
  final QuoteCacheDao quote_cache_dao;
  final MarketSessionResolver session_resolver;

  /// 取得目前需要輪詢的代號清單（由 repository 注入，通常來自持倉）。
  final Future<List<String>> Function() ProvideTrackedSymbols;

  final Map<String, StockQuote> latest_quotes = <String, StockQuote>{};
  DateTime? last_updated_at; // 最後一次成功更新報價的時間
  MarketSession current_session = MarketSession.closed;
  bool is_quote_unavailable = false; // 連續失敗中，UI 顯示「報價暫時無法取得」

  Timer? _poll_timer;
  bool _is_running = false;

  QuotePollingScheduler({
    required this.quote_service,
    required this.quote_cache_dao,
    required this.ProvideTrackedSymbols,
    MarketSessionResolver? session_resolver,
  }) : session_resolver = session_resolver ?? MarketSessionResolver();

  /// 是否正在輪詢中。
  bool get is_running => _is_running;

  /*
   *  @fn      Future<void> Start()
   *
   *  @brief   ( 啟動背景輪詢：先載入資料庫快取，再立即抓一次並排程下一輪 )
   *
   *  @return  None
   *
   *  @note    重複呼叫無害；休市時段不發網路請求。
   */
  Future<void> Start() async {
    if (_is_running) {
      return;
    }
    _is_running = true;
    await LoadCachedQuotesFromDatabase();
    await _PollOnceAndScheduleNext();
  }

  /// 停止背景輪詢。
  void Stop() {
    _is_running = false;
    _poll_timer?.cancel();
    _poll_timer = null;
  }

  /// 從資料庫載入快取報價（離線啟動時 UI 仍有資料可顯示）。
  Future<void> LoadCachedQuotesFromDatabase() async {
    final List<StockQuote> cached = await quote_cache_dao.GetAllCachedQuotes();
    for (final StockQuote quote in cached) {
      latest_quotes[quote.symbol] = quote;
      if (last_updated_at == null ||
          quote.fetched_at.isAfter(last_updated_at!)) {
        last_updated_at = quote.fetched_at;
      }
    }
    current_session = session_resolver.ResolveCurrentMarketSession();
    notifyListeners();
  }

  /*
   *  @fn      Future<bool> PollQuotesNow()
   *
   *  @brief   ( 立即抓取一次全部追蹤代號的報價並寫入快取 )
   *
   *  @return  true 表示成功取得至少一檔報價
   *
   *  @note    手動更新按鈕與排程共用此方法；失敗不拋例外。
   */
  Future<bool> PollQuotesNow() async {
    current_session = session_resolver.ResolveCurrentMarketSession();
    final List<String> symbols = await ProvideTrackedSymbols();
    if (symbols.isEmpty) {
      notifyListeners();
      return false;
    }

    final Map<String, StockQuote> fetched =
        await quote_service.FetchRealtimeQuotes(symbols);
    if (fetched.isEmpty) {
      is_quote_unavailable = true;
      notifyListeners();
      return false;
    }

    latest_quotes.addAll(fetched);
    last_updated_at = DateTime.now();
    is_quote_unavailable = false;
    await quote_cache_dao.SaveQuotes(fetched.values);
    notifyListeners();
    return true;
  }

  /// 抓一次報價並依目前時段排程下一輪。
  Future<void> _PollOnceAndScheduleNext() async {
    if (!_is_running) {
      return;
    }
    current_session = session_resolver.ResolveCurrentMarketSession();
    if (current_session != MarketSession.closed) {
      await PollQuotesNow();
    } else {
      notifyListeners(); // 休市：只更新時段顯示，不發請求
    }

    if (!_is_running) {
      return;
    }
    final Duration interval = ResolvePollInterval(current_session);
    _poll_timer = Timer(interval, _PollOnceAndScheduleNext);
  }

  /// 依時段決定輪詢間隔。
  Duration ResolvePollInterval(MarketSession session) {
    switch (session) {
      case MarketSession.regular:
        return REGULAR_POLL_INTERVAL;
      case MarketSession.premarket:
      case MarketSession.postmarket:
        return EXTENDED_POLL_INTERVAL;
      case MarketSession.closed:
        return CLOSED_CHECK_INTERVAL;
    }
  }

  @override
  void dispose() {
    Stop();
    super.dispose();
  }
}

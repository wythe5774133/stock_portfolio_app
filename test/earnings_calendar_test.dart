// 財報行事曆測試：Yahoo 財報欄位解析、台股法定期限、近期事件篩選、
// .ics 輸出格式，以及控制器的財報快取流程。全程使用 MockClient，不打真網路。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/logic/portfolio_repository.dart';
import 'package:stock_portfolio_app/models/earnings_event.dart';
import 'package:stock_portfolio_app/services/app_settings_store.dart';
import 'package:stock_portfolio_app/services/earnings_calendar_service.dart';
import 'package:stock_portfolio_app/services/market_session_resolver.dart';
import 'package:stock_portfolio_app/services/yahoo_quote_service.dart';
import 'package:stock_portfolio_app/ui/dashboard_controller.dart';

import 'test_database.dart';

/// DateTime（UTC）轉 epoch 秒。
int ToEpochSeconds(DateTime utc) => utc.millisecondsSinceEpoch ~/ 1000;

/// 2026/11/18 16:20 EST（盤後）＝ 21:20 UTC ＝ 台灣 11/19 05:20。
final DateTime NVDA_AFTER_CLOSE_UTC = DateTime.utc(2026, 11, 18, 21, 20);

/// 2026/10/27 07:00 EDT（盤前）＝ 11:00 UTC。
final DateTime KO_BEFORE_OPEN_UTC = DateTime.utc(2026, 10, 27, 11, 0);

void main() {
  setUpAll(MarketSessionResolver.InitializeTimeZoneDatabase);

  final DateTime now = DateTime.utc(2026, 10, 1, 4, 0);

  group('ParseEarningsFromV7QuoteJson', () {
    test('確定日期＋盤後：時段、美東日期、台灣時間文字', () {
      final EarningsEvent? event =
          EarningsCalendarService.ParseEarningsFromV7QuoteJson(
        <String, dynamic>{
          'symbol': 'NVDA',
          'earningsTimestamp': ToEpochSeconds(NVDA_AFTER_CLOSE_UTC),
          'earningsTimestampStart': ToEpochSeconds(NVDA_AFTER_CLOSE_UTC),
          'earningsTimestampEnd': ToEpochSeconds(NVDA_AFTER_CLOSE_UTC),
          'isEarningsDateEstimate': false,
        },
        now,
      );
      expect(event, isNotNull);
      expect(event!.symbol, 'NVDA');
      expect(event.kind, EarningsEventKind.us_earnings);
      expect(event.event_date, 20261118);
      expect(event.end_date, isNull);
      expect(event.is_estimate, isFalse);
      expect(event.timing, EarningsTiming.after_close);
      expect(event.event_time_utc, NVDA_AFTER_CLOSE_UTC);
      expect(EarningsCalendarService.ResolveTaipeiDisplayDate(event), 20261119);
      expect(EarningsCalendarService.FormatEventWhenText(event),
          '台灣時間 11/19（四）05:20・盤後');
    });

    test('盤前公布', () {
      final EarningsEvent? event =
          EarningsCalendarService.ParseEarningsFromV7QuoteJson(
        <String, dynamic>{
          'symbol': 'KO',
          'earningsTimestamp': ToEpochSeconds(KO_BEFORE_OPEN_UTC),
        },
        now,
      );
      expect(event!.timing, EarningsTiming.before_open);
      expect(event.event_date, 20261027);
    });

    test('預估區間：標為預估、時段未定、顯示日期區間', () {
      final EarningsEvent? event =
          EarningsCalendarService.ParseEarningsFromV7QuoteJson(
        <String, dynamic>{
          'symbol': 'AAPL',
          'earningsTimestamp': ToEpochSeconds(DateTime.utc(2026, 10, 28, 20)),
          'earningsTimestampStart':
              ToEpochSeconds(DateTime.utc(2026, 10, 28, 20)),
          'earningsTimestampEnd': ToEpochSeconds(DateTime.utc(2026, 11, 3, 21)),
          'isEarningsDateEstimate': true,
        },
        now,
      );
      expect(event!.is_estimate, isTrue);
      expect(event.timing, EarningsTiming.unknown);
      expect(event.event_time_utc, isNull);
      expect(event.event_date, 20261028);
      expect(event.end_date, 20261103);
      expect(EarningsCalendarService.FormatEventWhenText(event),
          '預估 美東 10/28～11/3');
    });

    test('UTC 00:00 視為只有日期：時間未定', () {
      final EarningsEvent? event =
          EarningsCalendarService.ParseEarningsFromV7QuoteJson(
        <String, dynamic>{
          'symbol': 'MSFT',
          'earningsTimestamp': ToEpochSeconds(DateTime.utc(2026, 10, 28)),
        },
        now,
      );
      expect(event!.event_date, 20261028);
      expect(event.timing, EarningsTiming.unknown);
      expect(event.event_time_utc, isNull);
      expect(EarningsCalendarService.FormatEventWhenText(event),
          '美東 10/28（三）・時間未定');
    });

    test('已過去的財報日與缺少欄位回傳 null', () {
      expect(
        EarningsCalendarService.ParseEarningsFromV7QuoteJson(
          <String, dynamic>{
            'symbol': 'NVDA',
            'earningsTimestamp': ToEpochSeconds(DateTime.utc(2026, 8, 27, 20)),
          },
          now,
        ),
        isNull,
      );
      expect(
        EarningsCalendarService.ParseEarningsFromV7QuoteJson(
          <String, dynamic>{'symbol': 'VOO', 'regularMarketPrice': 600.0},
          now,
        ),
        isNull,
      );
    });
  });

  group('BuildTaiwanStatutoryEvents', () {
    test('月營收每月 10 日、Q3 財報 11/14', () {
      final List<EarningsEvent> events =
          EarningsCalendarService.BuildTaiwanStatutoryEvents(
              '2330.TW', 20260930, 20261114);
      expect(
        events.map((EarningsEvent e) => (e.event_date, e.label)).toList(),
        <(int, String)>[
          (20261010, '9月營收'),
          (20261110, '10月營收'),
          (20261114, 'Q3 財報'),
        ],
      );
      expect(events.every((EarningsEvent e) => e.is_deadline), isTrue);
    });

    test('3 月含前一年年報、1 月為 12 月營收', () {
      final List<EarningsEvent> march =
          EarningsCalendarService.BuildTaiwanStatutoryEvents(
              '2317.TW', 20260301, 20260331);
      expect(
        march.map((EarningsEvent e) => (e.event_date, e.label)).toList(),
        <(int, String)>[(20260310, '2月營收'), (20260331, '2025 年報')],
      );
      final List<EarningsEvent> january =
          EarningsCalendarService.BuildTaiwanStatutoryEvents(
              '2317.TW', 20260101, 20260131);
      expect(january.single.label, '12月營收');
    });

    test('ETF 不列法定期限', () {
      expect(
        EarningsCalendarService.BuildTaiwanStatutoryEvents(
            '0050.TW', 20260101, 20261231),
        isEmpty,
      );
    });
  });

  group('SelectUpcomingEvents', () {
    final EarningsEvent nvda = EarningsEvent(
      symbol: 'NVDA',
      kind: EarningsEventKind.us_earnings,
      event_date: 20261118,
      event_time_utc: NVDA_AFTER_CLOSE_UTC,
      timing: EarningsTiming.after_close,
      label: '財報',
    );
    const EarningsEvent aapl = EarningsEvent(
      symbol: 'AAPL',
      kind: EarningsEventKind.us_earnings,
      event_date: 20261215,
      label: '財報',
    );

    test('合併美股與台股、依時間排序、排除範圍外與 ETF', () {
      final List<EarningsEvent> events =
          EarningsCalendarService.SelectUpcomingEvents(
        <String>['NVDA', '2330.TW', '0050.TW', 'AAPL'],
        <String, EarningsEvent>{'NVDA': nvda, 'AAPL': aapl},
        20261110,
        14,
      );
      expect(
        events.map((EarningsEvent e) => '${e.symbol} ${e.label}').toList(),
        <String>['2330.TW 10月營收', '2330.TW Q3 財報', 'NVDA 財報'],
      );
    });

    test('距今天數以台灣日期計算', () {
      expect(EarningsCalendarService.CalculateDaysUntil(nvda, 20261118), 1);
      expect(EarningsCalendarService.FormatDaysUntilText(0), '今天');
      expect(EarningsCalendarService.FormatDaysUntilText(1), '明天');
      expect(EarningsCalendarService.FormatDaysUntilText(5), '5 天後');
    });

    test('代號分類：只有美股個股需要查 Yahoo', () {
      expect(EarningsCalendarService.IsUsEarningsSymbol('NVDA'), isTrue);
      expect(EarningsCalendarService.IsUsEarningsSymbol('^GSPC'), isFalse);
      expect(EarningsCalendarService.IsUsEarningsSymbol('TWD=X'), isFalse);
      expect(EarningsCalendarService.IsUsEarningsSymbol('2330.TW'), isFalse);
    });
  });

  group('BuildEarningsIcs', () {
    final List<EarningsEvent> events = <EarningsEvent>[
      EarningsEvent(
        symbol: 'NVDA',
        kind: EarningsEventKind.us_earnings,
        event_date: 20261118,
        event_time_utc: NVDA_AFTER_CLOSE_UTC,
        timing: EarningsTiming.after_close,
        label: '財報',
      ),
      const EarningsEvent(
        symbol: '2330.TW',
        kind: EarningsEventKind.tw_monthly_revenue,
        event_date: 20261110,
        label: '10月營收',
      ),
    ];
    final String ics = EarningsCalendarService.BuildEarningsIcs(
        events, DateTime.utc(2026, 10, 1, 8, 30));

    test('CRLF 分行、定時與全天事件、提醒', () {
      expect(ics.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
      expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
      expect(ics, contains('DTSTAMP:20261001T083000Z'));
      expect(ics, contains('DTSTART:20261118T212000Z'));
      expect(ics, contains('DTEND:20261118T222000Z'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261110'));
      expect(ics, contains('DTEND;VALUE=DATE:20261111'));
      expect(ics, contains('UID:NVDA-us_earnings-20261118@stock-portfolio-app'));
      expect(ics, contains('TRIGGER:-PT12H'));
      expect(ics, contains('TRIGGER:-PT15H'));
      expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
    });

    test('每行不超過 75 位元組、逗號已跳脫', () {
      for (final String line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      final String unfolded = ics.replaceAll('\r\n ', '');
      expect(unfolded, contains('SUMMARY:NVDA 財報（盤後）'));
      expect(unfolded, contains('SUMMARY:2330.TW 10月營收（法定期限）'));
      expect(unfolded, contains('公司可能提前公布；遇假日可能順延。'));
      expect(unfolded, isNot(contains('提前公布;')));
    });
  });

  test('EarningsEvent JSON 來回轉換', () {
    final EarningsEvent original = EarningsEvent(
      symbol: 'NVDA',
      kind: EarningsEventKind.us_earnings,
      event_date: 20261118,
      end_date: 20261120,
      event_time_utc: NVDA_AFTER_CLOSE_UTC,
      is_estimate: true,
      timing: EarningsTiming.after_close,
      label: '財報',
    );
    final EarningsEvent? restored = EarningsEvent.FromJson(
      jsonDecode(jsonEncode(original.ToJson())) as Map<String, dynamic>,
    );
    expect(restored, isNotNull);
    expect(restored!.symbol, 'NVDA');
    expect(restored.event_date, 20261118);
    expect(restored.end_date, 20261120);
    expect(restored.event_time_utc, NVDA_AFTER_CLOSE_UTC);
    expect(restored.is_estimate, isTrue);
    expect(restored.timing, EarningsTiming.after_close);
    expect(EarningsEvent.FromJson(<String, dynamic>{'symbol': 'X'}), isNull);
  });

  group('FetchUsEarningsEvents', () {
    test('帶 fields 參數查 v7，解析出財報事件', () async {
      Uri? quote_uri;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'fc.yahoo.com') {
          return http.Response('', 404,
              headers: <String, String>{'set-cookie': 'A3=d=test; Path=/'});
        }
        if (request.url.path.contains('getcrumb')) {
          return http.Response('TestCrumb', 200);
        }
        quote_uri = request.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'quoteResponse': <String, dynamic>{
              'result': <dynamic>[
                <String, dynamic>{
                  'symbol': 'NVDA',
                  'earningsTimestamp': ToEpochSeconds(NVDA_AFTER_CLOSE_UTC),
                },
                <String, dynamic>{'symbol': 'VOO'},
              ],
            },
          }),
          200,
        );
      });
      final EarningsCalendarService service = EarningsCalendarService(
          quote_service: YahooQuoteService(http_client: client));
      final Map<String, EarningsEvent>? events =
          await service.FetchUsEarningsEvents(<String>['NVDA', 'VOO'], now);
      expect(events, isNotNull);
      expect(events!.keys, <String>['NVDA']);
      expect(quote_uri!.queryParameters['fields'],
          YahooQuoteService.EARNINGS_FIELDS);
      expect(quote_uri!.queryParameters['crumb'], 'TestCrumb');
    });

    test('請求失敗回傳 null', () async {
      final MockClient client = MockClient(
          (http.Request request) async => http.Response('error', 500));
      final EarningsCalendarService service = EarningsCalendarService(
          quote_service: YahooQuoteService(http_client: client));
      expect(await service.FetchUsEarningsEvents(<String>['NVDA'], now),
          isNull);
    });
  });

  group('DashboardController 財報快取', () {
    late AppDatabase database;
    late DashboardController controller;
    late Directory temp_dir;
    late int quote_request_count;
    late DateTime upcoming_utc;

    setUp(() {
      quote_request_count = 0;
      // 三天後 21:20 UTC（美東盤後），保證落在 14 天範圍內
      final DateTime base = DateTime.now().toUtc().add(const Duration(days: 3));
      upcoming_utc = DateTime.utc(base.year, base.month, base.day, 21, 20);
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'fc.yahoo.com') {
          return http.Response('', 404,
              headers: <String, String>{'set-cookie': 'A3=d=test; Path=/'});
        }
        if (request.url.path.contains('getcrumb')) {
          return http.Response('TestCrumb', 200);
        }
        if (request.url.path.contains('/v7/finance/quote')) {
          quote_request_count++;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'quoteResponse': <String, dynamic>{
                'result': <dynamic>[
                  <String, dynamic>{
                    'symbol': 'NVDA',
                    'earningsTimestamp': ToEpochSeconds(upcoming_utc),
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Too Many Requests', 429);
      });
      database = CreateTestDatabase();
      temp_dir = Directory.systemTemp.createTempSync('earnings_test');
      controller = DashboardController(
        repository: PortfolioRepository(database: database, http_client: client),
        settings_store: AppSettingsStore(override_directory: temp_dir),
      );
    });

    tearDown(() async {
      controller.repository.quote_scheduler.Stop();
      controller.dispose();
      await database.close();
      temp_dir.deleteSync(recursive: true);
    });

    test('首次抓取後寫入快取，12 小時內不重抓；新增代號才重抓', () async {
      await controller.repository.AddToWatchlist('NVDA', 'NVIDIA');
      await controller.ReloadWatchlist();

      await controller.RefreshEarningsCalendar();
      expect(quote_request_count, 1);
      expect(controller.us_earnings_by_symbol.keys, <String>['NVDA']);
      expect(
        controller
            .GetUpcomingEarningsEvents()
            .map((EarningsEvent e) => e.symbol),
        contains('NVDA'),
      );
      expect(controller.GetEarningsBadgeEvent('NVDA'), isNotNull);

      // 快取有效：不再發請求，且重新載入後仍讀得到
      await controller.RefreshEarningsCalendar();
      expect(quote_request_count, 1);
      final Map<String, dynamic> settings =
          await AppSettingsStore(override_directory: temp_dir).LoadSettings();
      expect(settings[DashboardController.SETTING_KEY_EARNINGS_CACHE],
          isA<Map<String, dynamic>>());

      // 備份不含財報快取
      final Map<String, dynamic> backup =
          jsonDecode(await controller.ExportBackupJson())
              as Map<String, dynamic>;
      expect(
        (backup['settings'] as Map<String, dynamic>)
            .containsKey(DashboardController.SETTING_KEY_EARNINGS_CACHE),
        isFalse,
      );

      // 新增追蹤代號 → 重抓
      await controller.repository.AddToWatchlist('AAPL', 'Apple');
      await controller.ReloadWatchlist();
      await controller.RefreshEarningsCalendar();
      expect(quote_request_count, 2);

      // .ics 匯出含 NVDA
      expect(controller.BuildEarningsCalendarIcs(), contains('NVDA'));
    });
  });
}

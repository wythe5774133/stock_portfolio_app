// 儀表板 widget 測試：以記憶體資料庫 + MockClient 驗證
// 匯入後的統計卡片、持倉列表、展開明細與報價顯示（不打真網路）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/logic/portfolio_repository.dart';
import 'package:stock_portfolio_app/services/app_settings_store.dart';
import 'package:stock_portfolio_app/ui/dashboard_controller.dart';
import 'package:stock_portfolio_app/ui/dashboard_page.dart';

/// 產生單檔 v7 報價 JSON。
Map<String, dynamic> BuildV7Quote(String symbol, double price) {
  return <String, dynamic>{
    'symbol': symbol,
    'marketState': 'REGULAR',
    'regularMarketPrice': price,
    'regularMarketTime': 1783713600,
    'regularMarketPreviousClose': price - 1,
  };
}

/// 模擬 Yahoo：v7 報價與代號搜尋成功、歷史日線一律 429（走快取為空的 fallback）。
MockClient BuildMockYahooClient() {
  return MockClient((http.Request request) async {
    if (request.url.host == 'fc.yahoo.com') {
      return http.Response('', 404,
          headers: <String, String>{'set-cookie': 'A3=d=test; Path=/'});
    }
    if (request.url.path.contains('getcrumb')) {
      return http.Response('TestCrumb', 200);
    }
    if (request.url.path.contains('/v1/finance/search')) {
      return http.Response(
          jsonEncode(<String, dynamic>{
            'quotes': <dynamic>[
              <String, dynamic>{
                'symbol': 'NVDA',
                'longname': 'NVIDIA Corporation',
                'exchDisp': 'NASDAQ',
                'quoteType': 'EQUITY',
              },
            ],
          }),
          200);
    }
    if (request.url.path.contains('/v7/finance/quote')) {
      final List<String> symbols =
          (request.url.queryParameters['symbols'] ?? '').split(',');
      final Map<String, double> prices = <String, double>{
        'NVDA': 210.96,
        'VOO': 585.32,
        'AAPL': 232.50,
        'GOOG': 201.44,
      };
      return http.Response(
          jsonEncode(<String, dynamic>{
            'quoteResponse': <String, dynamic>{
              'result': <dynamic>[
                for (final String s in symbols)
                  if (prices.containsKey(s)) BuildV7Quote(s, prices[s]!),
              ],
            },
          }),
          200);
    }
    return http.Response('Too Many Requests', 429); // 歷史日線走快取
  });
}

void main() {
  late AppDatabase database;
  late PortfolioRepository repository;
  late DashboardController controller;
  late Directory temp_dir;

  setUp(() {
    database = AppDatabase.Memory();
    repository = PortfolioRepository(
      database: database,
      http_client: BuildMockYahooClient(),
    );
    temp_dir = Directory.systemTemp.createTempSync('settings_test');
    controller = DashboardController(
      repository: repository,
      settings_store: AppSettingsStore(override_directory: temp_dir),
    );
  });

  tearDown(() async {
    repository.quote_scheduler.Stop();
    controller.dispose();
    await database.close();
    temp_dir.deleteSync(recursive: true);
  });

  /// 建立測試 App 外殼。
  Widget BuildTestApp() {
    return ChangeNotifierProvider<DashboardController>.value(
      value: controller,
      child: const MaterialApp(home: DashboardPage()),
    );
  }

  testWidgets('空資料庫：顯示空狀態提示', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    expect(find.text('尚無持倉，請先匯入交易紀錄 CSV'), findsOneWidget);
    expect(find.text('匯入 CSV'), findsOneWidget);
  });

  testWidgets('匯入 CSV 後：統計卡片、持倉列表與報價正確呈現',
      (WidgetTester tester) async {
    final String csv_content =
        File('test/fixtures/sample_transactions.csv').readAsStringSync();

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.ImportCsvContent(csv_content);
      repository.quote_scheduler.Stop();
    });

    // 放大測試視窗，容納完整儀表板
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 統計卡片
    expect(find.text('總資產'), findsOneWidget);
    expect(find.text('總成本'), findsWidgets);
    expect(find.text('未實現損益'), findsWidgets);
    expect(find.text('已實現損益'), findsWidgets);

    // 三種圖表區塊
    expect(find.text('資產曲線'), findsOneWidget);
    expect(find.text('持倉配置（依市值）'), findsOneWidget);
    expect(find.text('成本配置（依投入成本）'), findsOneWidget);

    // 持倉列表與成本方法標示
    expect(find.text('持倉明細'), findsOneWidget);
    expect(find.textContaining('加權平均法'), findsOneWidget);
    expect(find.text('NVDA'), findsWidgets);
    expect(find.text('VOO'), findsWidgets);
    expect(find.text('AAPL'), findsWidgets);
    expect(find.text('GOOG'), findsWidgets);

    // 報價已抓到（NVDA 現價出現在列表中）
    expect(find.text(r'$210.96'), findsWidgets);
  });

  testWidgets('點擊持倉列展開交易明細', (WidgetTester tester) async {
    final String csv_content =
        File('test/fixtures/sample_transactions.csv').readAsStringSync();

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.ImportCsvContent(csv_content);
      repository.quote_scheduler.Stop();
    });

    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 展開 NVDA 的持倉列（鎖定 ExpansionTile，避免點到圓餅圖圖例的代號文字）
    final Finder nvda_tile = find.widgetWithText(ExpansionTile, 'NVDA');
    await tester.ensureVisible(nvda_tile);
    await tester.pumpAndSettle();
    await tester.tap(nvda_tile);
    await tester.pumpAndSettle();

    expect(find.text('交易明細（4 筆）'), findsOneWidget);
    expect(find.text('買入'), findsWidgets);
    expect(find.text('賣出'), findsWidgets);
    expect(find.text('2026/07/07'), findsOneWidget);
  });

  testWidgets('手動記帳：搜尋代號→選定→自動帶現價→存檔後出現在持倉',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      repository.quote_scheduler.Stop();
    });

    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 開啟記帳對話框
    await tester.tap(find.text('記一筆'));
    await tester.pumpAndSettle();
    expect(find.text('記一筆交易'), findsOneWidget);

    // 輸入代號觸發搜尋（350ms 去抖動）
    await tester.enterText(find.byType(TextField).first, 'NVDA');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 50))); // 等 MockClient 回應
    await tester.pumpAndSettle();
    expect(find.text('NVIDIA Corporation'), findsOneWidget);

    // 選定建議：應顯示公司名稱並自動帶入現價
    await tester.tap(find.text('NVIDIA Corporation'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final TextField price_field = tester.widget<TextField>(
        find.widgetWithText(TextField, '價格').first);
    expect(price_field.controller!.text, '210.96');

    // 輸入股數並存檔
    await tester.enterText(find.widgetWithText(TextField, '股數'), '2');
    await tester.tap(find.text('儲存'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    // 對話框關閉、持倉出現 NVDA
    expect(find.text('記一筆交易'), findsNothing);
    expect(controller.holdings.length, 1);
    expect(controller.holdings.first.symbol, 'NVDA');
    expect(controller.holdings.first.net_quantity, closeTo(2.0, 1e-9));

    repository.quote_scheduler.Stop(); // 存檔流程會重啟輪詢，測試結束前停掉
  });

  testWidgets('已清倉個股顯示於已清倉區塊', (WidgetTester tester) async {
    const String csv_content =
        'Symbol,Current Price,Date,Time,Change,Open,High,Low,Volume,'
        'Trade Date,Purchase Price,Quantity,Commission,High Limit,Low Limit,'
        'Comment,Transaction Type\n'
        'TSLA,1,1,1,1,1,1,1,1,20260101,100.0,2.0,,,,,BUY\n'
        'TSLA,1,1,1,1,1,1,1,1,20260201,150.0,2.0,,,,,SELL\n';

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.ImportCsvContent(csv_content);
      repository.quote_scheduler.Stop();
    });

    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    expect(find.text('已清倉'), findsOneWidget);
    expect(find.text('TSLA'), findsOneWidget);
    // 已實現損益 (150-100)*2 = +100
    expect(find.textContaining('+\$100.00'), findsWidgets);
  });
}

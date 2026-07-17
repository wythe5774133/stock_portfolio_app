// 多幣別 UI 測試：市場分組節標題、台股原生幣別、總覽幣別切換與匯率提示、
// 記帳對話框依代號切換幣別前綴。以記憶體資料庫 + MockClient 驗證（不打真網路）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

import 'test_database.dart';
import 'package:stock_portfolio_app/logic/portfolio_repository.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/app_settings_store.dart';
import 'package:stock_portfolio_app/ui/dashboard_controller.dart';
import 'package:stock_portfolio_app/ui/home_shell.dart';

/*
 *  @fn      MockClient BuildMockClient(Map<String, double> prices)
 *
 *  @brief   ( 模擬 Yahoo：v7 報價只回傳 prices 內的代號，其餘管線走 429/空 )
 *
 *  @param   prices - 代號 → 報價；未列入者不回傳（可用於製造「無匯率」情境）
 *
 *  @return  MockClient；歷史日線一律 429（走空快取 fallback）
 */
MockClient BuildMockClient(Map<String, double> prices) {
  return MockClient((http.Request request) async {
    if (request.url.host == 'fc.yahoo.com') {
      return http.Response('', 404,
          headers: <String, String>{'set-cookie': 'A3=d=test; Path=/'});
    }
    if (request.url.path.contains('getcrumb')) {
      return http.Response('TestCrumb', 200);
    }
    if (request.url.path.contains('/v1/finance/search')) {
      return http.Response('{"quotes":[]}', 200);
    }
    if (request.url.path.contains('/v7/finance/quote')) {
      final List<String> symbols =
          (request.url.queryParameters['symbols'] ?? '').split(',');
      return http.Response(
          '{"quoteResponse":{"result":[${<String>[
            for (final String s in symbols)
              if (prices.containsKey(s)) _EncodeQuote(s, prices[s]!),
          ].join(',')}]}}',
          200);
    }
    return http.Response('Too Many Requests', 429);
  });
}

/// 將單筆報價編為 JSON 片段。
String _EncodeQuote(String symbol, double price) {
  return '{"symbol":"$symbol","marketState":"REGULAR",'
      '"regularMarketPrice":$price,"regularMarketTime":1783713600,'
      '"regularMarketPreviousClose":${price - 1}}';
}

void main() {
  late AppDatabase database;
  late PortfolioRepository repository;
  late DashboardController controller;
  late Directory temp_dir;

  /// 依指定報價表建立測試環境。
  void SetUpWith(Map<String, double> prices) {
    database = CreateTestDatabase();
    repository = PortfolioRepository(
      database: database,
      http_client: BuildMockClient(prices),
    );
    temp_dir = Directory.systemTemp.createTempSync('multi_currency_ui_test');
    controller = DashboardController(
      repository: repository,
      settings_store: AppSettingsStore(override_directory: temp_dir),
    );
  }

  tearDown(() async {
    repository.quote_scheduler.Stop();
    controller.dispose();
    await database.close();
    temp_dir.deleteSync(recursive: true);
  });

  Widget BuildTestApp() {
    return ChangeNotifierProvider<DashboardController>.value(
      value: controller,
      child: const MaterialApp(home: HomeShell()),
    );
  }

  /// 建立測試用買入交易。
  StockTransaction Buy(String symbol, int date, double price, double qty) {
    return StockTransaction(
      symbol: symbol,
      trade_date: date,
      purchase_price: price,
      quantity: qty,
      transaction_type: TransactionType.buy,
    );
  }

  void SetWideViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('混幣別持倉：出現「美股」「台股」節標題，台股列價格含 NT\$',
      (WidgetTester tester) async {
    SetUpWith(<String, double>{
      'NVDA': 210.96,
      '2330.TW': 1000.0,
      'TWD=X': 32.0,
    });
    SetWideViewport(tester);

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.AddManualTransaction(Buy('NVDA', 20260105, 200, 1));
      await controller.AddManualTransaction(Buy('2330.TW', 20260401, 950, 10));
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 切到持倉分頁
    await tester.tap(find.text('持倉').first);
    await tester.pumpAndSettle();

    // 混市場 → 兩個市場節標題都出現
    expect(find.text('美股'), findsOneWidget);
    expect(find.text('台股'), findsOneWidget);
    // 台股列價格為台幣（NT$）
    expect(find.textContaining('NT\$'), findsWidgets);

    repository.quote_scheduler.Stop();
  });

  testWidgets('單一市場持倉：不顯示市場節標題', (WidgetTester tester) async {
    SetUpWith(<String, double>{'NVDA': 210.96});
    SetWideViewport(tester);

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.AddManualTransaction(Buy('NVDA', 20260105, 200, 1));
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    await tester.tap(find.text('持倉').first);
    await tester.pumpAndSettle();

    // 全美股 → 無「美股」「台股」節標題（維持現狀外觀）
    expect(find.text('美股'), findsNothing);
    expect(find.text('台股'), findsNothing);

    repository.quote_scheduler.Stop();
  });

  testWidgets('總覽幣別切換：TWD 顯示 NT\$，切回 USD 恢復 \$',
      (WidgetTester tester) async {
    SetUpWith(<String, double>{
      'NVDA': 210.96,
      '2330.TW': 1000.0,
      'TWD=X': 32.0,
    });
    SetWideViewport(tester);

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.AddManualTransaction(Buy('NVDA', 20260105, 200, 1));
      await controller.AddManualTransaction(Buy('2330.TW', 20260401, 950, 10));
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 切換為 TWD（直接驅動 controller，較不受非同步輪詢影響）
    await tester.runAsync(() async {
      await controller.SwitchDisplayCurrency(DashboardController.CURRENCY_TWD);
    });
    await tester.pump();

    // 匯率已取得 → 生效幣別為 TWD → 聚合金額為 NT$，並顯示目前匯率
    expect(controller.display_currency_effective,
        DashboardController.CURRENCY_TWD);
    expect(find.textContaining('NT\$'), findsWidgets);
    expect(find.textContaining('1 USD = 32.00 TWD'), findsOneWidget);

    // 切回 USD → 聚合金額恢復 $，畫面不再出現 NT$
    await tester.runAsync(() async {
      await controller.SwitchDisplayCurrency(DashboardController.CURRENCY_USD);
    });
    await tester.pump();
    expect(find.textContaining('NT\$'), findsNothing);

    repository.quote_scheduler.Stop();
  });

  testWidgets('無匯率切 TWD：顯示「匯率取得中」且金額仍為 \$',
      (WidgetTester tester) async {
    // 全美股組合、mock 不回傳 TWD=X → 匯率恆為 null
    SetUpWith(<String, double>{'NVDA': 210.96});
    SetWideViewport(tester);

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.AddManualTransaction(Buy('NVDA', 20260105, 200, 1));
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    await tester.runAsync(() async {
      await controller.SwitchDisplayCurrency(DashboardController.CURRENCY_TWD);
    });
    await tester.pump();

    // 想看 TWD 但無匯率 → 生效幣別退回 USD
    expect(controller.usd_twd_rate, isNull);
    expect(controller.display_currency_effective,
        DashboardController.CURRENCY_USD);
    expect(find.text('匯率取得中，暫以美元顯示'), findsOneWidget);
    // 金額仍為美元，畫面不出現 NT$
    expect(find.textContaining('NT\$'), findsNothing);

    repository.quote_scheduler.Stop();
  });

  testWidgets('記帳對話框：輸入 2330.TW 後價格前綴變 NT\$',
      (WidgetTester tester) async {
    SetUpWith(<String, double>{'NVDA': 210.96, '2330.TW': 1000.0});
    SetWideViewport(tester);

    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    // 開記帳對話框
    await tester.tap(find.text('記一筆'));
    await tester.pumpAndSettle();
    expect(find.text('記一筆交易'), findsOneWidget);

    // 預設前綴為美元
    TextField price_field =
        tester.widget<TextField>(find.widgetWithText(TextField, '價格'));
    expect(price_field.decoration!.prefixText, '\$ ');

    // 輸入台股代號 → 前綴切換為 NT$
    await tester.enterText(find.widgetWithText(TextField, '股票代號'), '2330.TW');
    await tester.pump();
    price_field =
        tester.widget<TextField>(find.widgetWithText(TextField, '價格'));
    expect(price_field.decoration!.prefixText, 'NT\$ ');

    repository.quote_scheduler.Stop();
  });
}

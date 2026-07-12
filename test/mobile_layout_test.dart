// 手機尺寸（iPhone 390x844 邏輯解析度）的跑版防護測試：
// 任何 RenderFlex overflow 都會以例外形式讓測試失敗。
// 另含刪除交易功能測試。

import 'dart:convert';
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

/// 模擬 Yahoo：報價成功、其他 429。
MockClient BuildMockClient() {
  return MockClient((http.Request request) async {
    if (request.url.host == 'fc.yahoo.com') {
      return http.Response('', 404,
          headers: <String, String>{'set-cookie': 'A3=d=test; Path=/'});
    }
    if (request.url.path.contains('getcrumb')) {
      return http.Response('TestCrumb', 200);
    }
    if (request.url.path.contains('/v7/finance/quote')) {
      final List<String> symbols =
          (request.url.queryParameters['symbols'] ?? '').split(',');
      return http.Response(
          jsonEncode(<String, dynamic>{
            'quoteResponse': <String, dynamic>{
              'result': <dynamic>[
                for (final String s in symbols)
                  <String, dynamic>{
                    'symbol': s,
                    'regularMarketPrice': 726.41,
                    'regularMarketPreviousClose': 723.23,
                  },
              ],
            },
          }),
          200);
    }
    return http.Response('Too Many Requests', 429);
  });
}

void main() {
  late AppDatabase database;
  late PortfolioRepository repository;
  late DashboardController controller;
  late Directory temp_dir;

  setUp(() {
    database = CreateTestDatabase();
    repository = PortfolioRepository(
      database: database,
      http_client: BuildMockClient(),
    );
    temp_dir = Directory.systemTemp.createTempSync('mobile_test');
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

  Widget BuildTestApp() {
    return ChangeNotifierProvider<DashboardController>.value(
      value: controller,
      child: const MaterialApp(home: HomeShell()),
    );
  }

  /// 設定 iPhone 尺寸視窗。
  void SetIphoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> PrepareDataAndPump(WidgetTester tester) async {
    final String csv_content =
        File('test/fixtures/sample_transactions.csv').readAsStringSync();
    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.ImportCsvContent(csv_content);
      await controller.AddToWatchlist('QQQ', 'Invesco QQQ Trust',
          group_name: 'ETF');
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();
  }

  testWidgets('iPhone 尺寸：總覽分頁無 overflow', (WidgetTester tester) async {
    SetIphoneViewport(tester);
    await PrepareDataAndPump(tester);
    // 底部分頁存在（手機模式）
    expect(find.byType(NavigationBar), findsOneWidget);
    // 捲到最底確認整頁可渲染
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -2000));
    await tester.pump();
  });

  testWidgets('iPhone 尺寸：持倉分頁展開明細無 overflow',
      (WidgetTester tester) async {
    SetIphoneViewport(tester);
    await PrepareDataAndPump(tester);
    await tester.tap(find.text('持倉'));
    await tester.pumpAndSettle();
    final Finder tile = find.widgetWithText(ExpansionTile, 'NVDA');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('交易明細（4 筆）'), findsOneWidget);
  });

  testWidgets('iPhone 尺寸：自選分頁（含分類 chips）無 overflow',
      (WidgetTester tester) async {
    SetIphoneViewport(tester);
    await PrepareDataAndPump(tester);
    await tester.tap(find.text('自選'));
    await tester.pumpAndSettle();
    expect(find.text('QQQ'), findsOneWidget);
  });

  testWidgets('iPhone 尺寸：設定分頁無 overflow', (WidgetTester tester) async {
    SetIphoneViewport(tester);
    await PrepareDataAndPump(tester);
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('股息追蹤'), findsOneWidget);
  });

  testWidgets('刪除交易：確認後持倉重算', (WidgetTester tester) async {
    SetIphoneViewport(tester);
    await tester.runAsync(() async {
      await controller.InitializeDashboard();
      await controller.AddManualTransaction(const StockTransaction(
        symbol: 'TSLA',
        trade_date: 20260101,
        purchase_price: 400,
        quantity: 2,
        transaction_type: TransactionType.buy,
      ));
      await controller.AddManualTransaction(const StockTransaction(
        symbol: 'TSLA',
        trade_date: 20260201,
        purchase_price: 410,
        quantity: 1,
        transaction_type: TransactionType.buy,
      ));
      repository.quote_scheduler.Stop();
    });
    await tester.pumpWidget(BuildTestApp());
    await tester.pump();

    await tester.tap(find.text('持倉'));
    await tester.pumpAndSettle();
    final Finder tile = find.widgetWithText(ExpansionTile, 'TSLA');
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // 點第一筆（最新的 20260201）的刪除按鈕
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('刪除交易'), findsOneWidget);
    await tester.tap(find.text('刪除'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    // 剩 1 筆交易、持股 2 股
    expect(controller.holdings.single.transactions.length, 1);
    expect(controller.holdings.single.net_quantity, closeTo(2.0, 1e-9));

    repository.quote_scheduler.Stop();
  });
}

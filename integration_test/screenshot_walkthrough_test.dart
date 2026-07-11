// UI 走查工具：在模擬器上實際啟動 App，逐一切換四個分頁並截圖，
// 供開發時人工檢查畫面是否跑版。搭配 test_driver/integration_test.dart 使用：
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_walkthrough_test.dart -d <裝置>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';
import 'package:stock_portfolio_app/database/database_connection.dart';
import 'package:stock_portfolio_app/main.dart' as app;
import 'package:stock_portfolio_app/services/csv_transaction_importer.dart';

/// 走查用的範例交易（與 test/fixtures 相同內容）。
const String WALKTHROUGH_CSV = '''
Symbol,Current Price,Date,Time,Change,Open,High,Low,Volume,Trade Date,Purchase Price,Quantity,Commission,High Limit,Low Limit,Comment,Transaction Type
NVDA,210.96,2026/07/10,16:00 EDT,8.18001,201.92,211.0,201.92,147203662,20260707,194.478914,0.77129,,,,,BUY
NVDA,210.96,2026/07/10,16:00 EDT,8.18001,201.92,211.0,201.92,147203662,20260613,205.0,0.41538,,,,,SELL
NVDA,210.96,2026/07/10,16:00 EDT,8.18001,201.92,211.0,201.92,147203662,20260501,178.25,1.5,,,,,BUY
NVDA,210.96,2026/07/10,16:00 EDT,8.18001,201.92,211.0,201.92,147203662,20260310,152.6,2.0,,,,,BUY
VOO,585.32,2026/07/10,16:00 EDT,3.21,580.11,586.0,579.85,4203662,20260405,545.5,1.0,,,,,BUY
VOO,585.32,2026/07/10,16:00 EDT,3.21,580.11,586.0,579.85,4203662,20260505,558.75,1.0,,,,,BUY
AAPL,232.5,2026/07/10,16:00 EDT,1.05,230.9,233.1,230.2,52036620,20260220,241.8,3.0,,,,,BUY
AAPL,232.5,2026/07/10,16:00 EDT,1.05,230.9,233.1,230.2,52036620,20260415,215.4,2.0,,,,,BUY
GOOG,201.44,2026/07/10,16:00 EDT,-0.88,202.0,203.5,200.7,18203662,20260115,192.3,2.5,,,,,BUY
''';

/// 啟動 App 前先灌測試資料（flutter drive 重裝 App 會清掉容器資料）。
Future<void> SeedWalkthroughData() async {
  final AppDatabase database = AppDatabase(OpenConnection());
  await CsvTransactionImporter()
      .ImportCsvIntoDatabase(WALKTHROUGH_CSV, database.transactionDao);
  await database.watchlistDao
      .AddSymbol('QQQ', 'Invesco QQQ Trust', 1, group_name: 'ETF');
  await database.watchlistDao
      .AddSymbol('TSM', 'Taiwan Semiconductor', 2, group_name: 'AI 概念股');
  await database.close();
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('四分頁截圖走查', (WidgetTester tester) async {
    await SeedWalkthroughData();
    app.main();
    // 等資料載入與首輪報價
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    await binding.takeScreenshot('tab0_overview');

    // 捲到總覽底部（圓餅圖＋配置明細）
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -1600));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('tab0_overview_bottom');

    await tester.tap(find.text('持倉'));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('tab1_holdings');

    // 展開第一檔持倉看明細
    final Finder first_tile = find.byType(ExpansionTile).first;
    await tester.tap(first_tile);
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('tab1_holdings_expanded');

    await tester.tap(find.text('自選'));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('tab2_watchlist');

    await tester.tap(find.text('設定'));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('tab3_settings');
  });
}

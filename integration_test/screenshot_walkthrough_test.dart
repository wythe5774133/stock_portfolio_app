// UI 走查工具：在模擬器上實際啟動 App，逐一切換四個分頁並截圖，
// 供開發時人工檢查畫面是否跑版。搭配 test_driver/integration_test.dart 使用：
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_walkthrough_test.dart -d <裝置>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_portfolio_app/main.dart' as app;

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('四分頁截圖走查', (WidgetTester tester) async {
    app.main();
    // 等資料載入與首輪報價
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    await binding.takeScreenshot('tab0_overview');

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

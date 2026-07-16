// 測試共用：建立記憶體資料庫（NativeDatabase 只能在原生測試環境使用，
// 因此獨立於 lib/，避免 dart:ffi 進入網頁版建置）。

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

/// 建立單元測試用的記憶體資料庫。
AppDatabase CreateTestDatabase() {
  // 每次都建立獨立的記憶體 executor；同一測試同時模擬多裝置屬預期行為。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

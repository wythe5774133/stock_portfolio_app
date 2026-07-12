// 測試共用：建立記憶體資料庫（NativeDatabase 只能在原生測試環境使用，
// 因此獨立於 lib/，避免 dart:ffi 進入網頁版建置）。

import 'package:drift/native.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

/// 建立單元測試用的記憶體資料庫。
AppDatabase CreateTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

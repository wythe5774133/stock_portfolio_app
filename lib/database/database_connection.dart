// 正式環境的資料庫連線：由 drift_flutter 依平台自動選擇——
// 桌面/手機用檔案型 SQLite（應用文件目錄），網頁用 WebAssembly SQLite
// （資料存在瀏覽器的 OPFS/IndexedDB，不經過任何伺服器）。

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// 建立正式環境資料庫連線（名稱對應既有的 stock_portfolio.sqlite）。
DatabaseConnection OpenConnection() {
  return driftDatabase(
    name: 'stock_portfolio',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

// 正式環境的資料庫連線：以 path_provider 取得應用文件目錄。
// 與 app_database.dart 分離，讓 schema 與 DAO 保持純 Dart 可測。

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 建立落地於應用文件目錄的資料庫連線（正式環境使用）。
LazyDatabase OpenConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String db_path = p.join(dir.path, 'stock_portfolio.sqlite');
    return NativeDatabase(File(db_path));
  });
}

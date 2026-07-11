// App 設定儲存：以 JSON 檔案落地於應用文件目錄（目前僅漲跌配色慣例）。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AppSettingsStore
 *
 * @brief   讀寫使用者偏好設定（settings.json），讀取失敗回傳預設值。
 */
class AppSettingsStore {
  static const String SETTINGS_FILE_NAME = 'settings.json';

  /// 測試時可注入自訂目錄；null 表示使用應用文件目錄。
  final Directory? override_directory;

  const AppSettingsStore({this.override_directory});

  /// 讀取全部設定；檔案不存在或損毀時回傳空 map。
  Future<Map<String, dynamic>> LoadSettings() async {
    try {
      final File file = await _ResolveSettingsFile();
      if (!file.existsSync()) {
        return <String, dynamic>{};
      }
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// 合併寫入設定（保留既有其他鍵值）。
  Future<void> SaveSetting(String key, Object? value) async {
    try {
      final Map<String, dynamic> settings = await LoadSettings();
      settings[key] = value;
      final File file = await _ResolveSettingsFile();
      file.writeAsStringSync(jsonEncode(settings));
    } catch (_) {
      // 設定寫入失敗不影響主要功能
    }
  }

  /// 取得設定檔位置。
  Future<File> _ResolveSettingsFile() async {
    final Directory dir =
        override_directory ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, SETTINGS_FILE_NAME));
  }
}

// 設定儲存後端（原生實作）：JSON 檔案存於應用文件目錄。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 讀取全部設定；檔案不存在或損毀回傳空 map。
Future<Map<String, dynamic>> LoadSettingsFromBackend(
    Object? override_directory) async {
  try {
    final File file = await _ResolveSettingsFile(override_directory);
    if (!file.existsSync()) {
      return <String, dynamic>{};
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// 寫入全部設定。
Future<void> SaveSettingsToBackend(
    Object? override_directory, Map<String, dynamic> settings) async {
  try {
    final File file = await _ResolveSettingsFile(override_directory);
    file.writeAsStringSync(jsonEncode(settings));
  } catch (_) {
    // 設定寫入失敗不影響主要功能
  }
}

/// 取得設定檔位置（測試可注入自訂目錄）。
Future<File> _ResolveSettingsFile(Object? override_directory) async {
  final Directory dir = override_directory is Directory
      ? override_directory
      : await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'settings.json'));
}

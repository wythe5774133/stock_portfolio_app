// App 設定儲存：原生平台存 JSON 檔案、網頁存 localStorage，
// 由條件匯出的後端實作處理平台差異。

import 'platform_io/settings_backend_io.dart'
    if (dart.library.js_interop) 'platform_io/settings_backend_web.dart'
    as backend;

/*
 * @author  Toby
 *
 * @date    2026/07/12
 *
 * @class   AppSettingsStore
 *
 * @brief   讀寫使用者偏好設定，讀取失敗回傳預設值。
 */
class AppSettingsStore {
  /// 測試時可注入自訂目錄（原生平台限定；網頁忽略）。
  final Object? override_directory;

  const AppSettingsStore({this.override_directory});

  /// 讀取全部設定；不存在或損毀時回傳空 map。
  Future<Map<String, dynamic>> LoadSettings() {
    return backend.LoadSettingsFromBackend(override_directory);
  }

  /// 合併寫入設定（保留既有其他鍵值）。
  Future<void> SaveSetting(String key, Object? value) async {
    final Map<String, dynamic> settings = await LoadSettings();
    settings[key] = value;
    await backend.SaveSettingsToBackend(override_directory, settings);
  }
}

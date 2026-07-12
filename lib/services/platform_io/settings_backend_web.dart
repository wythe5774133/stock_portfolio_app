// 設定儲存後端（網頁實作）：shared_preferences（底層為 localStorage）。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _SETTINGS_KEY = 'settings_json';

/// 讀取全部設定；不存在或損毀回傳空 map。
Future<Map<String, dynamic>> LoadSettingsFromBackend(
    Object? override_directory) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_SETTINGS_KEY);
    if (raw == null) {
      return <String, dynamic>{};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// 寫入全部設定。
Future<void> SaveSettingsToBackend(
    Object? override_directory, Map<String, dynamic> settings) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_SETTINGS_KEY, jsonEncode(settings));
  } catch (_) {
    // 設定寫入失敗不影響主要功能
  }
}

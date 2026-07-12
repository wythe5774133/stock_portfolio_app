// 環境變數讀取（原生平台實作）。

import 'dart:io';

/// 讀取環境變數（開發輔助用）；不存在回傳 null。
String? ReadEnvironmentVariable(String key) {
  return Platform.environment[key];
}

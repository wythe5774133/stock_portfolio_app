// 備份存檔（網頁實作）：以瀏覽器下載方式存檔。

import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

/// 觸發瀏覽器下載備份檔；一律回傳 true。
Future<bool> SaveBackupToDevice(String backup_json, String file_name) async {
  final XFile file = XFile.fromData(
    Uint8List.fromList(utf8.encode(backup_json)),
    mimeType: 'application/json',
    name: file_name,
  );
  await file.saveTo(file_name);
  return true;
}

/// 觸發瀏覽器下載 .ics 行事曆檔（手機瀏覽器點開即可加入行事曆）；一律回傳 true。
Future<bool> SaveCalendarToDevice(String ics_content, String file_name) async {
  final XFile file = XFile.fromData(
    Uint8List.fromList(utf8.encode(ics_content)),
    mimeType: 'text/calendar',
    name: file_name,
  );
  await file.saveTo(file_name);
  return true;
}

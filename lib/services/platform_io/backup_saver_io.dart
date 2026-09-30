// 備份存檔（原生實作）：手機開分享面板、桌面開存檔對話框。

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 儲存備份內容；回傳 true 表示流程有完成（false = 使用者取消）。
Future<bool> SaveBackupToDevice(String backup_json, String file_name) async {
  if (Platform.isIOS || Platform.isAndroid) {
    // 手機：寫入暫存檔後開系統分享面板（存到檔案、AirDrop、雲端皆可）
    final Directory temp_dir = await getTemporaryDirectory();
    final File temp_file = File(p.join(temp_dir.path, file_name));
    await temp_file.writeAsString(backup_json);
    await SharePlus.instance.share(ShareParams(
      files: <XFile>[XFile(temp_file.path)],
      subject: '股票庫存備份',
    ));
    return true;
  }

  // 桌面：存檔對話框
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: file_name,
    acceptedTypeGroups: <XTypeGroup>[
      // iOS 需以 UTI 宣告型別（只給 extensions 會直接拋例外）
      const XTypeGroup(
        label: 'JSON',
        extensions: <String>['json'],
        uniformTypeIdentifiers: <String>['public.json'],
      ),
    ],
  );
  if (location == null) {
    return false; // 使用者取消
  }
  await File(location.path).writeAsString(backup_json);
  return true;
}

/// 儲存 .ics 行事曆檔：手機開分享面板（可直接加入行事曆）、桌面開存檔對話框。
Future<bool> SaveCalendarToDevice(String ics_content, String file_name) async {
  if (Platform.isIOS || Platform.isAndroid) {
    final Directory temp_dir = await getTemporaryDirectory();
    final File temp_file = File(p.join(temp_dir.path, file_name));
    await temp_file.writeAsString(ics_content);
    await SharePlus.instance.share(ShareParams(
      files: <XFile>[XFile(temp_file.path, mimeType: 'text/calendar')],
      subject: '財報行事曆',
    ));
    return true;
  }

  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: file_name,
    acceptedTypeGroups: <XTypeGroup>[
      const XTypeGroup(
        label: 'iCalendar',
        extensions: <String>['ics'],
        uniformTypeIdentifiers: <String>['com.apple.ical.ics'],
      ),
    ],
  );
  if (location == null) {
    return false; // 使用者取消
  }
  await File(location.path).writeAsString(ics_content);
  return true;
}

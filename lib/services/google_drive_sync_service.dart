// Google Drive 同步服務：以使用者自己的 Google 帳號登入，
// 把備份快照存在 Drive 的 App 專屬資料夾（appDataFolder，隱藏空間）。
// 同步流程：拉遠端快照 → 合併進本地（含墓碑）→ 推合併後快照。

import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'backup_service.dart';

/// 一次同步的結果統計。
class DriveSyncResult {
  final int pulled_transactions; // 從雲端合併進來的交易數
  final int pushed_bytes; // 推上雲端的快照大小
  final DateTime synced_at;

  const DriveSyncResult({
    required this.pulled_transactions,
    required this.pushed_bytes,
    required this.synced_at,
  });
}

/*
 * @author  Toby
 *
 * @date    2026/07/12
 *
 * @class   GoogleDriveSyncService
 *
 * @brief   Google 登入與 Drive appDataFolder 快照同步。
 *
 * @note    使用 drive.appdata scope：App 只能存取自己的隱藏資料夾，
 *          看不到使用者 Drive 的其他任何檔案（最小權限）。
 *          Drive REST 以注入的 http.Client 呼叫，單元測試可 mock。
 */
class GoogleDriveSyncService {
  /// iOS OAuth Client ID（macOS 共用；Android 之後在 Console 另建）
  static const String IOS_CLIENT_ID =
      '210888133557-r41nb6vti3j562qpdi0i855859dl5m2u.apps.googleusercontent.com';
  static const String SNAPSHOT_FILE_NAME = 'stock_portfolio_sync.json';
  static const String DRIVE_SCOPE =
      'https://www.googleapis.com/auth/drive.appdata';

  final BackupService backup_service;
  final http.Client http_client;
  final GoogleSignIn google_sign_in;

  GoogleSignInAccount? current_account;

  GoogleDriveSyncService({
    required this.backup_service,
    http.Client? http_client,
    GoogleSignIn? google_sign_in,
  })  : http_client = http_client ?? http.Client(),
        google_sign_in = google_sign_in ??
            GoogleSignIn(
              clientId: IOS_CLIENT_ID,
              scopes: const <String>[DRIVE_SCOPE],
            );

  /// 目前是否已登入。
  bool get is_signed_in => current_account != null;

  /// 登入帳號的 email（未登入為 null）。
  String? get account_email => current_account?.email;

  /// 互動式登入；成功回傳 true。
  Future<bool> SignIn() async {
    try {
      current_account = await google_sign_in.signIn();
      return current_account != null;
    } catch (_) {
      return false;
    }
  }

  /// 靜默登入（啟動時嘗試恢復前次登入，不跳視窗）。
  Future<bool> TrySilentSignIn() async {
    try {
      current_account = await google_sign_in.signInSilently();
      return current_account != null;
    } catch (_) {
      return false;
    }
  }

  /// 登出。
  Future<void> SignOut() async {
    try {
      await google_sign_in.signOut();
    } finally {
      current_account = null;
    }
  }

  /*
   *  @fn      Future<DriveSyncResult?> SyncNow(Map<String, dynamic> settings)
   *
   *  @brief   ( 執行一次雙向同步：拉遠端 → 合併 → 推合併結果 )
   *
   *  @param   settings - 目前設定（一併存入快照）
   *
   *  @return  同步統計；未登入或網路失敗回傳 null（不拋例外）
   */
  Future<DriveSyncResult?> SyncNow(Map<String, dynamic> settings) async {
    if (current_account == null) {
      return null;
    }
    try {
      final Map<String, String> headers = await current_account!.authHeaders;

      // 1. 找遠端快照
      final String? file_id = await _FindSnapshotFileId(headers);

      // 2. 有遠端快照 → 下載並合併進本地
      int pulled = 0;
      if (file_id != null) {
        final String? remote_json = await _DownloadFile(headers, file_id);
        if (remote_json != null && remote_json.isNotEmpty) {
          final BackupRestoreSummary summary =
              await backup_service.RestoreFromBackupJson(remote_json);
          pulled = summary.transactions_added;
        }
      }

      // 3. 推合併後的快照
      final String merged_json =
          await backup_service.BuildBackupJson(settings);
      await _UploadSnapshot(headers, file_id, merged_json);

      return DriveSyncResult(
        pulled_transactions: pulled,
        pushed_bytes: utf8.encode(merged_json).length,
        synced_at: DateTime.now(),
      );
    } catch (_) {
      return null; // 網路/權杖失敗：靜默，下次再同步
    }
  }

  /// 在 appDataFolder 找快照檔，回傳 file id（不存在為 null）。
  Future<String?> _FindSnapshotFileId(Map<String, String> headers) async {
    final Uri uri = Uri.https('www.googleapis.com', '/drive/v3/files',
        <String, String>{
          'spaces': 'appDataFolder',
          'q': "name = '$SNAPSHOT_FILE_NAME'",
          'fields': 'files(id, modifiedTime)',
        });
    final http.Response response =
        await http_client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw http.ClientException('Drive list failed: ${response.statusCode}');
    }
    final List<dynamic>? files =
        (jsonDecode(response.body) as Map<String, dynamic>)['files']
            as List<dynamic>?;
    if (files == null || files.isEmpty) {
      return null;
    }
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  /// 下載檔案內容。
  Future<String?> _DownloadFile(
      Map<String, String> headers, String file_id) async {
    final Uri uri = Uri.https('www.googleapis.com',
        '/drive/v3/files/$file_id', <String, String>{'alt': 'media'});
    final http.Response response =
        await http_client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      return null;
    }
    return utf8.decode(response.bodyBytes);
  }

  /// 上傳快照：已存在則更新內容，否則在 appDataFolder 新建。
  Future<void> _UploadSnapshot(
      Map<String, String> headers, String? file_id, String content) async {
    if (file_id != null) {
      // 更新既有檔案內容
      final Uri uri = Uri.https('www.googleapis.com',
          '/upload/drive/v3/files/$file_id', <String, String>{
        'uploadType': 'media',
      });
      final http.Response response = await http_client.patch(uri,
          headers: <String, String>{
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: utf8.encode(content));
      if (response.statusCode != 200) {
        throw http.ClientException(
            'Drive update failed: ${response.statusCode}');
      }
      return;
    }

    // 新建檔案（multipart：metadata + 內容）
    const String boundary = 'stock_portfolio_sync_boundary';
    final String metadata = jsonEncode(<String, dynamic>{
      'name': SNAPSHOT_FILE_NAME,
      'parents': <String>['appDataFolder'],
    });
    final String body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--';
    final Uri uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files',
        <String, String>{'uploadType': 'multipart'});
    final http.Response response = await http_client.post(uri,
        headers: <String, String>{
          ...headers,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: utf8.encode(body));
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Drive create failed: ${response.statusCode}');
    }
  }
}

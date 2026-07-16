// 備份服務：把交易紀錄、追蹤清單與設定打包成 JSON，供跨裝置轉移。
// 匯入採「合併」策略：交易靠唯一鍵去重、追蹤清單取聯集，不會蓋掉既有資料。

import 'dart:convert';

import '../database/app_database.dart';
import '../database/tombstone_dao.dart';
import '../models/stock_transaction.dart';

/// 匯入備份的結果統計。
class BackupRestoreSummary {
  final int transactions_added; // 新增交易筆數
  final int transactions_duplicated; // 重複略過筆數
  final int watchlist_added; // 新增追蹤數
  final Map<String, dynamic> settings; // 備份內的設定（由呼叫端套用）

  const BackupRestoreSummary({
    required this.transactions_added,
    required this.transactions_duplicated,
    required this.watchlist_added,
    required this.settings,
  });
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   BackupService
 *
 * @brief   備份檔的產生與還原。格式為單一 JSON：
 *          {format_version, exported_at, transactions[], watchlist[], settings{}}
 *
 * @note    還原為合併而非覆蓋：同一份備份匯入多次不會產生重複資料，
 *          兩台裝置各自記帳後互相匯入即可雙向補齊。
 */
class BackupService {
  static const int FORMAT_VERSION = 1;

  final AppDatabase database;

  const BackupService({required this.database});

  /*
   *  @fn      Future<String> BuildBackupJson(Map<String, dynamic> settings)
   *
   *  @brief   ( 將全部資料打包成 JSON 字串 )
   *
   *  @param   settings - 目前的使用者設定（settings.json 內容）
   *
   *  @return  美化排版的 JSON 備份內容
   */
  Future<String> BuildBackupJson(Map<String, dynamic> settings) async {
    final List<StockTransaction> transactions = await database.transactionDao
        .GetAllTransactions();
    final List<WatchlistSymbol> watchlist = await database.watchlistDao
        .GetAllSymbols();
    final List<SyncTombstone> tombstones = await database.tombstoneDao
        .GetAllTombstones();

    final Map<String, dynamic> backup = <String, dynamic>{
      'format_version': FORMAT_VERSION,
      'app': 'stock_portfolio_app',
      'exported_at': DateTime.now().toIso8601String(),
      'transactions': <Map<String, dynamic>>[
        for (final StockTransaction tx in transactions)
          <String, dynamic>{
            'symbol': tx.symbol,
            'trade_date': tx.trade_date,
            'purchase_price': tx.purchase_price,
            'quantity': tx.quantity,
            'transaction_type': FormatTransactionType(tx.transaction_type),
            if (tx.commission != null) 'commission': tx.commission,
            if (tx.comment != null) 'comment': tx.comment,
          },
      ],
      'watchlist': <Map<String, dynamic>>[
        for (final WatchlistSymbol w in watchlist)
          <String, dynamic>{
            'symbol': w.symbol,
            'name': w.name,
            'added_at': w.added_at,
            'group_name': w.group_name,
          },
      ],
      // 刪除墓碑：讓另一台裝置同步時同步刪除，而不是把資料「復活」
      'tombstones': <Map<String, dynamic>>[
        for (final SyncTombstone t in tombstones)
          <String, dynamic>{
            'kind': t.kind,
            'item_key': t.item_key,
            'deleted_at': t.deleted_at,
          },
      ],
      'settings': settings,
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /*
   *  @fn      Future<BackupRestoreSummary> RestoreFromBackupJson(String backup_json)
   *
   *  @brief   ( 解析備份 JSON 並合併進資料庫 )
   *
   *  @param   backup_json - 備份檔全文
   *
   *  @return  合併結果統計；格式不符時拋出 FormatException
   */
  Future<BackupRestoreSummary> RestoreFromBackupJson(String backup_json) async {
    final Map<String, dynamic> backup;
    try {
      backup = jsonDecode(backup_json) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('不是有效的 JSON 檔案');
    }
    if (backup['app'] != 'stock_portfolio_app' ||
        backup['format_version'] != FORMAT_VERSION) {
      throw const FormatException('不是本 App 的備份檔');
    }

    final dynamic raw_transactions = backup['transactions'];
    final dynamic raw_watchlist = backup['watchlist'];
    final dynamic raw_tombstones = backup['tombstones'];
    final dynamic raw_settings = backup['settings'];
    if ((raw_transactions != null && raw_transactions is! List<dynamic>) ||
        (raw_watchlist != null && raw_watchlist is! List<dynamic>) ||
        (raw_tombstones != null && raw_tombstones is! List<dynamic>) ||
        (raw_settings != null && raw_settings is! Map<String, dynamic>)) {
      throw const FormatException('備份檔欄位格式不正確');
    }

    // 匯入包含多張表的新增與刪除，必須全成全敗，避免中途失敗留下半套資料。
    return database.transaction<BackupRestoreSummary>(() async {
      return _RestoreValidatedBackup(backup);
    });
  }

  /// 將已完成基本格式驗證的備份套用至目前 transaction。
  Future<BackupRestoreSummary> _RestoreValidatedBackup(
    Map<String, dynamic> backup,
  ) async {
    // 步驟 1：先合併墓碑（遠端刪過的東西，本地也要刪掉且不再匯入）
    final List<dynamic> remote_tombstones =
        (backup['tombstones'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic raw in remote_tombstones) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String? kind = raw['kind'] as String?;
      final String? item_key = raw['item_key'] as String?;
      if (kind == null || item_key == null) {
        continue;
      }
      await database.tombstoneDao.AddTombstone(kind, item_key);
      // 套用刪除：本地若還有這個項目，刪掉
      if (kind == TombstoneDao.KIND_WATCHLIST) {
        await database.watchlistDao.RemoveSymbol(item_key);
      } else if (kind == TombstoneDao.KIND_TRANSACTION) {
        await _DeleteLocalTransactionByKey(item_key);
      }
    }
    final Set<String> transaction_tombstones = await database.tombstoneDao
        .GetTombstoneKeys(TombstoneDao.KIND_TRANSACTION);
    final Set<String> watchlist_tombstones = await database.tombstoneDao
        .GetTombstoneKeys(TombstoneDao.KIND_WATCHLIST);

    // 步驟 2：匯入交易（跳過墓碑名單內的）
    int added = 0;
    int duplicated = 0;
    final List<dynamic> transactions =
        (backup['transactions'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic raw in transactions) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final TransactionType? type = ParseTransactionType(
        (raw['transaction_type'] as String?) ?? '',
      );
      final String? symbol = raw['symbol'] as String?;
      final int? trade_date = raw['trade_date'] as int?;
      final num? price = raw['purchase_price'] as num?;
      final num? quantity = raw['quantity'] as num?;
      if (type == null ||
          symbol == null ||
          trade_date == null ||
          price == null ||
          quantity == null) {
        continue; // 缺欄位的紀錄跳過
      }
      final StockTransaction transaction = StockTransaction(
        symbol: symbol,
        trade_date: trade_date,
        purchase_price: price.toDouble(),
        quantity: quantity.toDouble(),
        transaction_type: type,
        commission: (raw['commission'] as num?)?.toDouble(),
        comment: raw['comment'] as String?,
      );
      if (transaction_tombstones.contains(
        TombstoneDao.BuildTransactionKey(transaction),
      )) {
        continue; // 這筆已被某台裝置刪除，不復活
      }
      final bool inserted = await database.transactionDao
          .InsertIgnoreTransaction(transaction);
      inserted ? added++ : duplicated++;
    }

    // 步驟 3：匯入追蹤清單（跳過墓碑名單內的）
    int watchlist_added = 0;
    final List<dynamic> watchlist =
        (backup['watchlist'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic raw in watchlist) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String? symbol = raw['symbol'] as String?;
      if (symbol == null || watchlist_tombstones.contains(symbol)) {
        continue;
      }
      final bool inserted = await database.watchlistDao.AddSymbol(
        symbol,
        (raw['name'] as String?) ?? symbol,
        (raw['added_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        group_name: (raw['group_name'] as String?) ?? '自選',
      );
      if (inserted) {
        watchlist_added++;
      }
    }

    return BackupRestoreSummary(
      transactions_added: added,
      transactions_duplicated: duplicated,
      watchlist_added: watchlist_added,
      settings:
          (backup['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  /// 依墓碑鍵刪除本地交易（找出符合唯一鍵的那筆）。
  Future<void> _DeleteLocalTransactionByKey(String item_key) async {
    final List<StockTransaction> all = await database.transactionDao
        .GetAllTransactions();
    for (final StockTransaction tx in all) {
      if (TombstoneDao.BuildTransactionKey(tx) == item_key && tx.id != null) {
        await database.transactionDao.DeleteTransactionById(tx.id!);
        return;
      }
    }
  }
}

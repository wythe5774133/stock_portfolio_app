// 備份/同步墓碑測試：刪除的交易與追蹤股在合併時不得復活，
// 且遠端墓碑要能刪掉本地資料。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio_app/database/app_database.dart';

import 'test_database.dart';
import 'package:stock_portfolio_app/database/tombstone_dao.dart';
import 'package:stock_portfolio_app/models/stock_transaction.dart';
import 'package:stock_portfolio_app/services/backup_service.dart';

const StockTransaction SAMPLE_TX = StockTransaction(
  symbol: 'NVDA',
  trade_date: 20260310,
  purchase_price: 152.6,
  quantity: 2.0,
  transaction_type: TransactionType.buy,
);

void main() {
  late AppDatabase database;
  late BackupService backup_service;

  setUp(() {
    database = CreateTestDatabase();
    backup_service = BackupService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  /// 模擬「裝置A」：新增交易後產出快照。
  Future<String> BuildSnapshotWithSampleTx() async {
    await database.transactionDao.InsertIgnoreTransaction(SAMPLE_TX);
    return backup_service.BuildBackupJson(<String, dynamic>{});
  }

  test('本地刪除後匯入舊快照：交易不復活', () async {
    final String old_snapshot = await BuildSnapshotWithSampleTx();

    // 刪除並留墓碑（模擬 repository.DeleteTransaction 的行為）
    final List<StockTransaction> all = await database.transactionDao
        .GetAllTransactions();
    await database.transactionDao.DeleteTransactionById(all.single.id!);
    await database.tombstoneDao.AddTombstone(
      TombstoneDao.KIND_TRANSACTION,
      TombstoneDao.BuildTransactionKey(SAMPLE_TX),
    );

    // 匯入還含有那筆交易的舊快照
    final BackupRestoreSummary summary =
        await backup_service.RestoreFromBackupJson(old_snapshot);
    expect(summary.transactions_added, 0); // 不復活
    expect(await database.transactionDao.GetAllTransactions(), isEmpty);
  });

  test('遠端墓碑會刪掉本地既有交易', () async {
    await database.transactionDao.InsertIgnoreTransaction(SAMPLE_TX);

    // 遠端快照：沒有交易、但帶著這筆的墓碑（另一台裝置刪的）
    final String remote_snapshot =
        '''
{
  "format_version": 1,
  "app": "stock_portfolio_app",
  "transactions": [],
  "watchlist": [],
  "tombstones": [
    {"kind": "transaction",
     "item_key": "${TombstoneDao.BuildTransactionKey(SAMPLE_TX)}",
     "deleted_at": 1}
  ],
  "settings": {}
}
''';
    await backup_service.RestoreFromBackupJson(remote_snapshot);
    expect(await database.transactionDao.GetAllTransactions(), isEmpty);
    // 墓碑也保存下來，之後推快照會帶著走
    final Set<String> keys = await database.tombstoneDao.GetTombstoneKeys(
      TombstoneDao.KIND_TRANSACTION,
    );
    expect(keys, contains(TombstoneDao.BuildTransactionKey(SAMPLE_TX)));
  });

  test('追蹤股墓碑：遠端刪除同步到本地且不再匯入', () async {
    await database.watchlistDao.AddSymbol('QQQ', 'Invesco QQQ', 1);

    final String remote_snapshot = '''
{
  "format_version": 1,
  "app": "stock_portfolio_app",
  "transactions": [],
  "watchlist": [
    {"symbol": "QQQ", "name": "Invesco QQQ", "added_at": 1}
  ],
  "tombstones": [
    {"kind": "watchlist", "item_key": "QQQ", "deleted_at": 2}
  ],
  "settings": {}
}
''';
    await backup_service.RestoreFromBackupJson(remote_snapshot);
    expect(await database.watchlistDao.GetAllSymbols(), isEmpty);
  });

  test('快照包含墓碑；重新加入會撤銷墓碑（透過快照往返驗證）', () async {
    // 刪除留墓碑
    await database.tombstoneDao.AddTombstone(
      TombstoneDao.KIND_TRANSACTION,
      TombstoneDao.BuildTransactionKey(SAMPLE_TX),
    );
    final String snapshot = await backup_service.BuildBackupJson(
      <String, dynamic>{},
    );
    expect(snapshot, contains('"tombstones"'));
    expect(snapshot, contains('NVDA|20260310'));

    // 重新加入 → 撤銷墓碑（模擬 repository.AddManualTransaction）
    await database.transactionDao.InsertIgnoreTransaction(SAMPLE_TX);
    await database.tombstoneDao.RemoveTombstone(
      TombstoneDao.KIND_TRANSACTION,
      TombstoneDao.BuildTransactionKey(SAMPLE_TX),
    );
    final Set<String> keys = await database.tombstoneDao.GetTombstoneKeys(
      TombstoneDao.KIND_TRANSACTION,
    );
    expect(keys, isEmpty);
  });

  test('追蹤清單分類經快照往返保留', () async {
    await database.watchlistDao.AddSymbol(
      'TSM',
      'Taiwan Semiconductor',
      1,
      group_name: 'AI 概念股',
    );
    final String snapshot = await backup_service.BuildBackupJson(
      <String, dynamic>{},
    );

    final AppDatabase other = CreateTestDatabase();
    final BackupService other_service = BackupService(database: other);
    await other_service.RestoreFromBackupJson(snapshot);
    final List<WatchlistSymbol> restored = await other.watchlistDao
        .GetAllSymbols();
    expect(restored.single.group_name, 'AI 概念股');
    await other.close();
  });

  test('未知備份版本在異動資料前即拒絕', () async {
    const String future_backup = '''
{"format_version": 99, "app": "stock_portfolio_app",
 "transactions": [], "watchlist": [], "tombstones": [], "settings": {}}
''';
    expect(
      () => backup_service.RestoreFromBackupJson(future_backup),
      throwsFormatException,
    );
    expect(await database.transactionDao.GetAllTransactions(), isEmpty);
  });

  test('欄位型別錯誤在異動資料前即拒絕', () async {
    const String malformed_backup = '''
{"format_version": 1, "app": "stock_portfolio_app",
 "transactions": "not-a-list", "watchlist": [], "tombstones": [], "settings": {}}
''';
    expect(
      () => backup_service.RestoreFromBackupJson(malformed_backup),
      throwsFormatException,
    );
    expect(await database.transactionDao.GetAllTransactions(), isEmpty);
  });

  test('匯入中途遇到壞資料時整批 rollback', () async {
    await database.transactionDao.InsertIgnoreTransaction(SAMPLE_TX);
    final String key = TombstoneDao.BuildTransactionKey(SAMPLE_TX);
    final String partially_invalid_backup =
        '''
{"format_version": 1, "app": "stock_portfolio_app",
 "tombstones": [{"kind": "transaction", "item_key": "$key"}],
 "transactions": [{"symbol": "AAPL", "trade_date": 20260101,
   "purchase_price": 200, "quantity": 1, "transaction_type": "BUY",
   "commission": "invalid"}],
 "watchlist": [], "settings": {}}
''';

    expect(
      () => backup_service.RestoreFromBackupJson(partially_invalid_backup),
      throwsA(anything),
    );
    final List<StockTransaction> remaining = await database.transactionDao
        .GetAllTransactions();
    expect(remaining.single.symbol, SAMPLE_TX.symbol);
    expect(
      await database.tombstoneDao.GetTombstoneKeys(
        TombstoneDao.KIND_TRANSACTION,
      ),
      isEmpty,
    );
  });
}

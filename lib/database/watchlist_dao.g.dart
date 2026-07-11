// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watchlist_dao.dart';

// ignore_for_file: type=lint
mixin _$WatchlistDaoMixin on DatabaseAccessor<AppDatabase> {
  $WatchlistSymbolsTable get watchlistSymbols =>
      attachedDatabase.watchlistSymbols;
  WatchlistDaoManager get managers => WatchlistDaoManager(this);
}

class WatchlistDaoManager {
  final _$WatchlistDaoMixin _db;
  WatchlistDaoManager(this._db);
  $$WatchlistSymbolsTableTableManager get watchlistSymbols =>
      $$WatchlistSymbolsTableTableManager(
        _db.attachedDatabase,
        _db.watchlistSymbols,
      );
}

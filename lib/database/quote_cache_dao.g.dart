// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$QuoteCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $QuoteCacheTable get quoteCache => attachedDatabase.quoteCache;
  QuoteCacheDaoManager get managers => QuoteCacheDaoManager(this);
}

class QuoteCacheDaoManager {
  final _$QuoteCacheDaoMixin _db;
  QuoteCacheDaoManager(this._db);
  $$QuoteCacheTableTableManager get quoteCache =>
      $$QuoteCacheTableTableManager(_db.attachedDatabase, _db.quoteCache);
}

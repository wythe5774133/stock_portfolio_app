// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tombstone_dao.dart';

// ignore_for_file: type=lint
mixin _$TombstoneDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncTombstonesTable get syncTombstones => attachedDatabase.syncTombstones;
  TombstoneDaoManager get managers => TombstoneDaoManager(this);
}

class TombstoneDaoManager {
  final _$TombstoneDaoMixin _db;
  TombstoneDaoManager(this._db);
  $$SyncTombstonesTableTableManager get syncTombstones =>
      $$SyncTombstonesTableTableManager(
        _db.attachedDatabase,
        _db.syncTombstones,
      );
}

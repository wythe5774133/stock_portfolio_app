// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dividend_dao.dart';

// ignore_for_file: type=lint
mixin _$DividendDaoMixin on DatabaseAccessor<AppDatabase> {
  $DividendEventsTable get dividendEvents => attachedDatabase.dividendEvents;
  DividendDaoManager get managers => DividendDaoManager(this);
}

class DividendDaoManager {
  final _$DividendDaoMixin _db;
  DividendDaoManager(this._db);
  $$DividendEventsTableTableManager get dividendEvents =>
      $$DividendEventsTableTableManager(
        _db.attachedDatabase,
        _db.dividendEvents,
      );
}

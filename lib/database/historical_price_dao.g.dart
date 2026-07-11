// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'historical_price_dao.dart';

// ignore_for_file: type=lint
mixin _$HistoricalPriceDaoMixin on DatabaseAccessor<AppDatabase> {
  $HistoricalPricesTable get historicalPrices =>
      attachedDatabase.historicalPrices;
  HistoricalPriceDaoManager get managers => HistoricalPriceDaoManager(this);
}

class HistoricalPriceDaoManager {
  final _$HistoricalPriceDaoMixin _db;
  HistoricalPriceDaoManager(this._db);
  $$HistoricalPricesTableTableManager get historicalPrices =>
      $$HistoricalPricesTableTableManager(
        _db.attachedDatabase,
        _db.historicalPrices,
      );
}

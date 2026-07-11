// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StockTransactionsTable extends StockTransactions
    with TableInfo<$StockTransactionsTable, StockTransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trade_dateMeta = const VerificationMeta(
    'trade_date',
  );
  @override
  late final GeneratedColumn<int> trade_date = GeneratedColumn<int>(
    'trade_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchase_priceMeta = const VerificationMeta(
    'purchase_price',
  );
  @override
  late final GeneratedColumn<double> purchase_price = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transaction_typeMeta = const VerificationMeta(
    'transaction_type',
  );
  @override
  late final GeneratedColumn<String> transaction_type = GeneratedColumn<String>(
    'transaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commissionMeta = const VerificationMeta(
    'commission',
  );
  @override
  late final GeneratedColumn<double> commission = GeneratedColumn<double>(
    'commission',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    trade_date,
    purchase_price,
    quantity,
    transaction_type,
    commission,
    comment,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockTransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('trade_date')) {
      context.handle(
        _trade_dateMeta,
        trade_date.isAcceptableOrUnknown(data['trade_date']!, _trade_dateMeta),
      );
    } else if (isInserting) {
      context.missing(_trade_dateMeta);
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchase_priceMeta,
        purchase_price.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchase_priceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchase_priceMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('transaction_type')) {
      context.handle(
        _transaction_typeMeta,
        transaction_type.isAcceptableOrUnknown(
          data['transaction_type']!,
          _transaction_typeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transaction_typeMeta);
    }
    if (data.containsKey('commission')) {
      context.handle(
        _commissionMeta,
        commission.isAcceptableOrUnknown(data['commission']!, _commissionMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {symbol, trade_date, purchase_price, quantity, transaction_type},
  ];
  @override
  StockTransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockTransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      trade_date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trade_date'],
      )!,
      purchase_price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      transaction_type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      commission: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}commission'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
    );
  }

  @override
  $StockTransactionsTable createAlias(String alias) {
    return $StockTransactionsTable(attachedDatabase, alias);
  }
}

class StockTransactionRow extends DataClass
    implements Insertable<StockTransactionRow> {
  final int id;
  final String symbol;
  final int trade_date;
  final double purchase_price;
  final double quantity;
  final String transaction_type;
  final double? commission;
  final String? comment;
  const StockTransactionRow({
    required this.id,
    required this.symbol,
    required this.trade_date,
    required this.purchase_price,
    required this.quantity,
    required this.transaction_type,
    this.commission,
    this.comment,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['trade_date'] = Variable<int>(trade_date);
    map['purchase_price'] = Variable<double>(purchase_price);
    map['quantity'] = Variable<double>(quantity);
    map['transaction_type'] = Variable<String>(transaction_type);
    if (!nullToAbsent || commission != null) {
      map['commission'] = Variable<double>(commission);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    return map;
  }

  StockTransactionsCompanion toCompanion(bool nullToAbsent) {
    return StockTransactionsCompanion(
      id: Value(id),
      symbol: Value(symbol),
      trade_date: Value(trade_date),
      purchase_price: Value(purchase_price),
      quantity: Value(quantity),
      transaction_type: Value(transaction_type),
      commission: commission == null && nullToAbsent
          ? const Value.absent()
          : Value(commission),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
    );
  }

  factory StockTransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockTransactionRow(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      trade_date: serializer.fromJson<int>(json['trade_date']),
      purchase_price: serializer.fromJson<double>(json['purchase_price']),
      quantity: serializer.fromJson<double>(json['quantity']),
      transaction_type: serializer.fromJson<String>(json['transaction_type']),
      commission: serializer.fromJson<double?>(json['commission']),
      comment: serializer.fromJson<String?>(json['comment']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'trade_date': serializer.toJson<int>(trade_date),
      'purchase_price': serializer.toJson<double>(purchase_price),
      'quantity': serializer.toJson<double>(quantity),
      'transaction_type': serializer.toJson<String>(transaction_type),
      'commission': serializer.toJson<double?>(commission),
      'comment': serializer.toJson<String?>(comment),
    };
  }

  StockTransactionRow copyWith({
    int? id,
    String? symbol,
    int? trade_date,
    double? purchase_price,
    double? quantity,
    String? transaction_type,
    Value<double?> commission = const Value.absent(),
    Value<String?> comment = const Value.absent(),
  }) => StockTransactionRow(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    trade_date: trade_date ?? this.trade_date,
    purchase_price: purchase_price ?? this.purchase_price,
    quantity: quantity ?? this.quantity,
    transaction_type: transaction_type ?? this.transaction_type,
    commission: commission.present ? commission.value : this.commission,
    comment: comment.present ? comment.value : this.comment,
  );
  StockTransactionRow copyWithCompanion(StockTransactionsCompanion data) {
    return StockTransactionRow(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      trade_date: data.trade_date.present
          ? data.trade_date.value
          : this.trade_date,
      purchase_price: data.purchase_price.present
          ? data.purchase_price.value
          : this.purchase_price,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      transaction_type: data.transaction_type.present
          ? data.transaction_type.value
          : this.transaction_type,
      commission: data.commission.present
          ? data.commission.value
          : this.commission,
      comment: data.comment.present ? data.comment.value : this.comment,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockTransactionRow(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('trade_date: $trade_date, ')
          ..write('purchase_price: $purchase_price, ')
          ..write('quantity: $quantity, ')
          ..write('transaction_type: $transaction_type, ')
          ..write('commission: $commission, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    trade_date,
    purchase_price,
    quantity,
    transaction_type,
    commission,
    comment,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockTransactionRow &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.trade_date == this.trade_date &&
          other.purchase_price == this.purchase_price &&
          other.quantity == this.quantity &&
          other.transaction_type == this.transaction_type &&
          other.commission == this.commission &&
          other.comment == this.comment);
}

class StockTransactionsCompanion extends UpdateCompanion<StockTransactionRow> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<int> trade_date;
  final Value<double> purchase_price;
  final Value<double> quantity;
  final Value<String> transaction_type;
  final Value<double?> commission;
  final Value<String?> comment;
  const StockTransactionsCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.trade_date = const Value.absent(),
    this.purchase_price = const Value.absent(),
    this.quantity = const Value.absent(),
    this.transaction_type = const Value.absent(),
    this.commission = const Value.absent(),
    this.comment = const Value.absent(),
  });
  StockTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required int trade_date,
    required double purchase_price,
    required double quantity,
    required String transaction_type,
    this.commission = const Value.absent(),
    this.comment = const Value.absent(),
  }) : symbol = Value(symbol),
       trade_date = Value(trade_date),
       purchase_price = Value(purchase_price),
       quantity = Value(quantity),
       transaction_type = Value(transaction_type);
  static Insertable<StockTransactionRow> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<int>? trade_date,
    Expression<double>? purchase_price,
    Expression<double>? quantity,
    Expression<String>? transaction_type,
    Expression<double>? commission,
    Expression<String>? comment,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (trade_date != null) 'trade_date': trade_date,
      if (purchase_price != null) 'purchase_price': purchase_price,
      if (quantity != null) 'quantity': quantity,
      if (transaction_type != null) 'transaction_type': transaction_type,
      if (commission != null) 'commission': commission,
      if (comment != null) 'comment': comment,
    });
  }

  StockTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<int>? trade_date,
    Value<double>? purchase_price,
    Value<double>? quantity,
    Value<String>? transaction_type,
    Value<double?>? commission,
    Value<String?>? comment,
  }) {
    return StockTransactionsCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      trade_date: trade_date ?? this.trade_date,
      purchase_price: purchase_price ?? this.purchase_price,
      quantity: quantity ?? this.quantity,
      transaction_type: transaction_type ?? this.transaction_type,
      commission: commission ?? this.commission,
      comment: comment ?? this.comment,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (trade_date.present) {
      map['trade_date'] = Variable<int>(trade_date.value);
    }
    if (purchase_price.present) {
      map['purchase_price'] = Variable<double>(purchase_price.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (transaction_type.present) {
      map['transaction_type'] = Variable<String>(transaction_type.value);
    }
    if (commission.present) {
      map['commission'] = Variable<double>(commission.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('trade_date: $trade_date, ')
          ..write('purchase_price: $purchase_price, ')
          ..write('quantity: $quantity, ')
          ..write('transaction_type: $transaction_type, ')
          ..write('commission: $commission, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }
}

class $QuoteCacheTable extends QuoteCache
    with TableInfo<$QuoteCacheTable, QuoteCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuoteCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regular_priceMeta = const VerificationMeta(
    'regular_price',
  );
  @override
  late final GeneratedColumn<double> regular_price = GeneratedColumn<double>(
    'regular_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regular_timeMeta = const VerificationMeta(
    'regular_time',
  );
  @override
  late final GeneratedColumn<int> regular_time = GeneratedColumn<int>(
    'regular_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pre_priceMeta = const VerificationMeta(
    'pre_price',
  );
  @override
  late final GeneratedColumn<double> pre_price = GeneratedColumn<double>(
    'pre_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pre_timeMeta = const VerificationMeta(
    'pre_time',
  );
  @override
  late final GeneratedColumn<int> pre_time = GeneratedColumn<int>(
    'pre_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _post_priceMeta = const VerificationMeta(
    'post_price',
  );
  @override
  late final GeneratedColumn<double> post_price = GeneratedColumn<double>(
    'post_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _post_timeMeta = const VerificationMeta(
    'post_time',
  );
  @override
  late final GeneratedColumn<int> post_time = GeneratedColumn<int>(
    'post_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previous_closeMeta = const VerificationMeta(
    'previous_close',
  );
  @override
  late final GeneratedColumn<double> previous_close = GeneratedColumn<double>(
    'previous_close',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _market_stateMeta = const VerificationMeta(
    'market_state',
  );
  @override
  late final GeneratedColumn<String> market_state = GeneratedColumn<String>(
    'market_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetched_atMeta = const VerificationMeta(
    'fetched_at',
  );
  @override
  late final GeneratedColumn<int> fetched_at = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    regular_price,
    regular_time,
    pre_price,
    pre_time,
    post_price,
    post_time,
    previous_close,
    market_state,
    fetched_at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quote_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuoteCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('regular_price')) {
      context.handle(
        _regular_priceMeta,
        regular_price.isAcceptableOrUnknown(
          data['regular_price']!,
          _regular_priceMeta,
        ),
      );
    }
    if (data.containsKey('regular_time')) {
      context.handle(
        _regular_timeMeta,
        regular_time.isAcceptableOrUnknown(
          data['regular_time']!,
          _regular_timeMeta,
        ),
      );
    }
    if (data.containsKey('pre_price')) {
      context.handle(
        _pre_priceMeta,
        pre_price.isAcceptableOrUnknown(data['pre_price']!, _pre_priceMeta),
      );
    }
    if (data.containsKey('pre_time')) {
      context.handle(
        _pre_timeMeta,
        pre_time.isAcceptableOrUnknown(data['pre_time']!, _pre_timeMeta),
      );
    }
    if (data.containsKey('post_price')) {
      context.handle(
        _post_priceMeta,
        post_price.isAcceptableOrUnknown(data['post_price']!, _post_priceMeta),
      );
    }
    if (data.containsKey('post_time')) {
      context.handle(
        _post_timeMeta,
        post_time.isAcceptableOrUnknown(data['post_time']!, _post_timeMeta),
      );
    }
    if (data.containsKey('previous_close')) {
      context.handle(
        _previous_closeMeta,
        previous_close.isAcceptableOrUnknown(
          data['previous_close']!,
          _previous_closeMeta,
        ),
      );
    }
    if (data.containsKey('market_state')) {
      context.handle(
        _market_stateMeta,
        market_state.isAcceptableOrUnknown(
          data['market_state']!,
          _market_stateMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetched_atMeta,
        fetched_at.isAcceptableOrUnknown(data['fetched_at']!, _fetched_atMeta),
      );
    } else if (isInserting) {
      context.missing(_fetched_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  QuoteCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuoteCacheData(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      regular_price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}regular_price'],
      ),
      regular_time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}regular_time'],
      ),
      pre_price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pre_price'],
      ),
      pre_time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pre_time'],
      ),
      post_price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}post_price'],
      ),
      post_time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_time'],
      ),
      previous_close: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}previous_close'],
      ),
      market_state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_state'],
      ),
      fetched_at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $QuoteCacheTable createAlias(String alias) {
    return $QuoteCacheTable(attachedDatabase, alias);
  }
}

class QuoteCacheData extends DataClass implements Insertable<QuoteCacheData> {
  final String symbol;
  final double? regular_price;
  final int? regular_time;
  final double? pre_price;
  final int? pre_time;
  final double? post_price;
  final int? post_time;
  final double? previous_close;
  final String? market_state;
  final int fetched_at;
  const QuoteCacheData({
    required this.symbol,
    this.regular_price,
    this.regular_time,
    this.pre_price,
    this.pre_time,
    this.post_price,
    this.post_time,
    this.previous_close,
    this.market_state,
    required this.fetched_at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    if (!nullToAbsent || regular_price != null) {
      map['regular_price'] = Variable<double>(regular_price);
    }
    if (!nullToAbsent || regular_time != null) {
      map['regular_time'] = Variable<int>(regular_time);
    }
    if (!nullToAbsent || pre_price != null) {
      map['pre_price'] = Variable<double>(pre_price);
    }
    if (!nullToAbsent || pre_time != null) {
      map['pre_time'] = Variable<int>(pre_time);
    }
    if (!nullToAbsent || post_price != null) {
      map['post_price'] = Variable<double>(post_price);
    }
    if (!nullToAbsent || post_time != null) {
      map['post_time'] = Variable<int>(post_time);
    }
    if (!nullToAbsent || previous_close != null) {
      map['previous_close'] = Variable<double>(previous_close);
    }
    if (!nullToAbsent || market_state != null) {
      map['market_state'] = Variable<String>(market_state);
    }
    map['fetched_at'] = Variable<int>(fetched_at);
    return map;
  }

  QuoteCacheCompanion toCompanion(bool nullToAbsent) {
    return QuoteCacheCompanion(
      symbol: Value(symbol),
      regular_price: regular_price == null && nullToAbsent
          ? const Value.absent()
          : Value(regular_price),
      regular_time: regular_time == null && nullToAbsent
          ? const Value.absent()
          : Value(regular_time),
      pre_price: pre_price == null && nullToAbsent
          ? const Value.absent()
          : Value(pre_price),
      pre_time: pre_time == null && nullToAbsent
          ? const Value.absent()
          : Value(pre_time),
      post_price: post_price == null && nullToAbsent
          ? const Value.absent()
          : Value(post_price),
      post_time: post_time == null && nullToAbsent
          ? const Value.absent()
          : Value(post_time),
      previous_close: previous_close == null && nullToAbsent
          ? const Value.absent()
          : Value(previous_close),
      market_state: market_state == null && nullToAbsent
          ? const Value.absent()
          : Value(market_state),
      fetched_at: Value(fetched_at),
    );
  }

  factory QuoteCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuoteCacheData(
      symbol: serializer.fromJson<String>(json['symbol']),
      regular_price: serializer.fromJson<double?>(json['regular_price']),
      regular_time: serializer.fromJson<int?>(json['regular_time']),
      pre_price: serializer.fromJson<double?>(json['pre_price']),
      pre_time: serializer.fromJson<int?>(json['pre_time']),
      post_price: serializer.fromJson<double?>(json['post_price']),
      post_time: serializer.fromJson<int?>(json['post_time']),
      previous_close: serializer.fromJson<double?>(json['previous_close']),
      market_state: serializer.fromJson<String?>(json['market_state']),
      fetched_at: serializer.fromJson<int>(json['fetched_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'regular_price': serializer.toJson<double?>(regular_price),
      'regular_time': serializer.toJson<int?>(regular_time),
      'pre_price': serializer.toJson<double?>(pre_price),
      'pre_time': serializer.toJson<int?>(pre_time),
      'post_price': serializer.toJson<double?>(post_price),
      'post_time': serializer.toJson<int?>(post_time),
      'previous_close': serializer.toJson<double?>(previous_close),
      'market_state': serializer.toJson<String?>(market_state),
      'fetched_at': serializer.toJson<int>(fetched_at),
    };
  }

  QuoteCacheData copyWith({
    String? symbol,
    Value<double?> regular_price = const Value.absent(),
    Value<int?> regular_time = const Value.absent(),
    Value<double?> pre_price = const Value.absent(),
    Value<int?> pre_time = const Value.absent(),
    Value<double?> post_price = const Value.absent(),
    Value<int?> post_time = const Value.absent(),
    Value<double?> previous_close = const Value.absent(),
    Value<String?> market_state = const Value.absent(),
    int? fetched_at,
  }) => QuoteCacheData(
    symbol: symbol ?? this.symbol,
    regular_price: regular_price.present
        ? regular_price.value
        : this.regular_price,
    regular_time: regular_time.present ? regular_time.value : this.regular_time,
    pre_price: pre_price.present ? pre_price.value : this.pre_price,
    pre_time: pre_time.present ? pre_time.value : this.pre_time,
    post_price: post_price.present ? post_price.value : this.post_price,
    post_time: post_time.present ? post_time.value : this.post_time,
    previous_close: previous_close.present
        ? previous_close.value
        : this.previous_close,
    market_state: market_state.present ? market_state.value : this.market_state,
    fetched_at: fetched_at ?? this.fetched_at,
  );
  QuoteCacheData copyWithCompanion(QuoteCacheCompanion data) {
    return QuoteCacheData(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      regular_price: data.regular_price.present
          ? data.regular_price.value
          : this.regular_price,
      regular_time: data.regular_time.present
          ? data.regular_time.value
          : this.regular_time,
      pre_price: data.pre_price.present ? data.pre_price.value : this.pre_price,
      pre_time: data.pre_time.present ? data.pre_time.value : this.pre_time,
      post_price: data.post_price.present
          ? data.post_price.value
          : this.post_price,
      post_time: data.post_time.present ? data.post_time.value : this.post_time,
      previous_close: data.previous_close.present
          ? data.previous_close.value
          : this.previous_close,
      market_state: data.market_state.present
          ? data.market_state.value
          : this.market_state,
      fetched_at: data.fetched_at.present
          ? data.fetched_at.value
          : this.fetched_at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuoteCacheData(')
          ..write('symbol: $symbol, ')
          ..write('regular_price: $regular_price, ')
          ..write('regular_time: $regular_time, ')
          ..write('pre_price: $pre_price, ')
          ..write('pre_time: $pre_time, ')
          ..write('post_price: $post_price, ')
          ..write('post_time: $post_time, ')
          ..write('previous_close: $previous_close, ')
          ..write('market_state: $market_state, ')
          ..write('fetched_at: $fetched_at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    regular_price,
    regular_time,
    pre_price,
    pre_time,
    post_price,
    post_time,
    previous_close,
    market_state,
    fetched_at,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuoteCacheData &&
          other.symbol == this.symbol &&
          other.regular_price == this.regular_price &&
          other.regular_time == this.regular_time &&
          other.pre_price == this.pre_price &&
          other.pre_time == this.pre_time &&
          other.post_price == this.post_price &&
          other.post_time == this.post_time &&
          other.previous_close == this.previous_close &&
          other.market_state == this.market_state &&
          other.fetched_at == this.fetched_at);
}

class QuoteCacheCompanion extends UpdateCompanion<QuoteCacheData> {
  final Value<String> symbol;
  final Value<double?> regular_price;
  final Value<int?> regular_time;
  final Value<double?> pre_price;
  final Value<int?> pre_time;
  final Value<double?> post_price;
  final Value<int?> post_time;
  final Value<double?> previous_close;
  final Value<String?> market_state;
  final Value<int> fetched_at;
  final Value<int> rowid;
  const QuoteCacheCompanion({
    this.symbol = const Value.absent(),
    this.regular_price = const Value.absent(),
    this.regular_time = const Value.absent(),
    this.pre_price = const Value.absent(),
    this.pre_time = const Value.absent(),
    this.post_price = const Value.absent(),
    this.post_time = const Value.absent(),
    this.previous_close = const Value.absent(),
    this.market_state = const Value.absent(),
    this.fetched_at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuoteCacheCompanion.insert({
    required String symbol,
    this.regular_price = const Value.absent(),
    this.regular_time = const Value.absent(),
    this.pre_price = const Value.absent(),
    this.pre_time = const Value.absent(),
    this.post_price = const Value.absent(),
    this.post_time = const Value.absent(),
    this.previous_close = const Value.absent(),
    this.market_state = const Value.absent(),
    required int fetched_at,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       fetched_at = Value(fetched_at);
  static Insertable<QuoteCacheData> custom({
    Expression<String>? symbol,
    Expression<double>? regular_price,
    Expression<int>? regular_time,
    Expression<double>? pre_price,
    Expression<int>? pre_time,
    Expression<double>? post_price,
    Expression<int>? post_time,
    Expression<double>? previous_close,
    Expression<String>? market_state,
    Expression<int>? fetched_at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (regular_price != null) 'regular_price': regular_price,
      if (regular_time != null) 'regular_time': regular_time,
      if (pre_price != null) 'pre_price': pre_price,
      if (pre_time != null) 'pre_time': pre_time,
      if (post_price != null) 'post_price': post_price,
      if (post_time != null) 'post_time': post_time,
      if (previous_close != null) 'previous_close': previous_close,
      if (market_state != null) 'market_state': market_state,
      if (fetched_at != null) 'fetched_at': fetched_at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuoteCacheCompanion copyWith({
    Value<String>? symbol,
    Value<double?>? regular_price,
    Value<int?>? regular_time,
    Value<double?>? pre_price,
    Value<int?>? pre_time,
    Value<double?>? post_price,
    Value<int?>? post_time,
    Value<double?>? previous_close,
    Value<String?>? market_state,
    Value<int>? fetched_at,
    Value<int>? rowid,
  }) {
    return QuoteCacheCompanion(
      symbol: symbol ?? this.symbol,
      regular_price: regular_price ?? this.regular_price,
      regular_time: regular_time ?? this.regular_time,
      pre_price: pre_price ?? this.pre_price,
      pre_time: pre_time ?? this.pre_time,
      post_price: post_price ?? this.post_price,
      post_time: post_time ?? this.post_time,
      previous_close: previous_close ?? this.previous_close,
      market_state: market_state ?? this.market_state,
      fetched_at: fetched_at ?? this.fetched_at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (regular_price.present) {
      map['regular_price'] = Variable<double>(regular_price.value);
    }
    if (regular_time.present) {
      map['regular_time'] = Variable<int>(regular_time.value);
    }
    if (pre_price.present) {
      map['pre_price'] = Variable<double>(pre_price.value);
    }
    if (pre_time.present) {
      map['pre_time'] = Variable<int>(pre_time.value);
    }
    if (post_price.present) {
      map['post_price'] = Variable<double>(post_price.value);
    }
    if (post_time.present) {
      map['post_time'] = Variable<int>(post_time.value);
    }
    if (previous_close.present) {
      map['previous_close'] = Variable<double>(previous_close.value);
    }
    if (market_state.present) {
      map['market_state'] = Variable<String>(market_state.value);
    }
    if (fetched_at.present) {
      map['fetched_at'] = Variable<int>(fetched_at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuoteCacheCompanion(')
          ..write('symbol: $symbol, ')
          ..write('regular_price: $regular_price, ')
          ..write('regular_time: $regular_time, ')
          ..write('pre_price: $pre_price, ')
          ..write('pre_time: $pre_time, ')
          ..write('post_price: $post_price, ')
          ..write('post_time: $post_time, ')
          ..write('previous_close: $previous_close, ')
          ..write('market_state: $market_state, ')
          ..write('fetched_at: $fetched_at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoricalPricesTable extends HistoricalPrices
    with TableInfo<$HistoricalPricesTable, HistoricalPrice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoricalPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _close_priceMeta = const VerificationMeta(
    'close_price',
  );
  @override
  late final GeneratedColumn<double> close_price = GeneratedColumn<double>(
    'close_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, date, close_price];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historical_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoricalPrice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('close_price')) {
      context.handle(
        _close_priceMeta,
        close_price.isAcceptableOrUnknown(
          data['close_price']!,
          _close_priceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_close_priceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {symbol, date},
  ];
  @override
  HistoricalPrice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoricalPrice(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      close_price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close_price'],
      )!,
    );
  }

  @override
  $HistoricalPricesTable createAlias(String alias) {
    return $HistoricalPricesTable(attachedDatabase, alias);
  }
}

class HistoricalPrice extends DataClass implements Insertable<HistoricalPrice> {
  final String symbol;
  final int date;
  final double close_price;
  const HistoricalPrice({
    required this.symbol,
    required this.date,
    required this.close_price,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<int>(date);
    map['close_price'] = Variable<double>(close_price);
    return map;
  }

  HistoricalPricesCompanion toCompanion(bool nullToAbsent) {
    return HistoricalPricesCompanion(
      symbol: Value(symbol),
      date: Value(date),
      close_price: Value(close_price),
    );
  }

  factory HistoricalPrice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoricalPrice(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<int>(json['date']),
      close_price: serializer.fromJson<double>(json['close_price']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<int>(date),
      'close_price': serializer.toJson<double>(close_price),
    };
  }

  HistoricalPrice copyWith({String? symbol, int? date, double? close_price}) =>
      HistoricalPrice(
        symbol: symbol ?? this.symbol,
        date: date ?? this.date,
        close_price: close_price ?? this.close_price,
      );
  HistoricalPrice copyWithCompanion(HistoricalPricesCompanion data) {
    return HistoricalPrice(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      close_price: data.close_price.present
          ? data.close_price.value
          : this.close_price,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalPrice(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('close_price: $close_price')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, date, close_price);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoricalPrice &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.close_price == this.close_price);
}

class HistoricalPricesCompanion extends UpdateCompanion<HistoricalPrice> {
  final Value<String> symbol;
  final Value<int> date;
  final Value<double> close_price;
  final Value<int> rowid;
  const HistoricalPricesCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.close_price = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoricalPricesCompanion.insert({
    required String symbol,
    required int date,
    required double close_price,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       close_price = Value(close_price);
  static Insertable<HistoricalPrice> custom({
    Expression<String>? symbol,
    Expression<int>? date,
    Expression<double>? close_price,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (close_price != null) 'close_price': close_price,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoricalPricesCompanion copyWith({
    Value<String>? symbol,
    Value<int>? date,
    Value<double>? close_price,
    Value<int>? rowid,
  }) {
    return HistoricalPricesCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      close_price: close_price ?? this.close_price,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (close_price.present) {
      map['close_price'] = Variable<double>(close_price.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalPricesCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('close_price: $close_price, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DividendEventsTable extends DividendEvents
    with TableInfo<$DividendEventsTable, DividendEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DividendEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ex_dateMeta = const VerificationMeta(
    'ex_date',
  );
  @override
  late final GeneratedColumn<int> ex_date = GeneratedColumn<int>(
    'ex_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amount_per_shareMeta = const VerificationMeta(
    'amount_per_share',
  );
  @override
  late final GeneratedColumn<double> amount_per_share = GeneratedColumn<double>(
    'amount_per_share',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, ex_date, amount_per_share];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dividend_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DividendEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('ex_date')) {
      context.handle(
        _ex_dateMeta,
        ex_date.isAcceptableOrUnknown(data['ex_date']!, _ex_dateMeta),
      );
    } else if (isInserting) {
      context.missing(_ex_dateMeta);
    }
    if (data.containsKey('amount_per_share')) {
      context.handle(
        _amount_per_shareMeta,
        amount_per_share.isAcceptableOrUnknown(
          data['amount_per_share']!,
          _amount_per_shareMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amount_per_shareMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {symbol, ex_date},
  ];
  @override
  DividendEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DividendEvent(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      ex_date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ex_date'],
      )!,
      amount_per_share: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_per_share'],
      )!,
    );
  }

  @override
  $DividendEventsTable createAlias(String alias) {
    return $DividendEventsTable(attachedDatabase, alias);
  }
}

class DividendEvent extends DataClass implements Insertable<DividendEvent> {
  final String symbol;
  final int ex_date;
  final double amount_per_share;
  const DividendEvent({
    required this.symbol,
    required this.ex_date,
    required this.amount_per_share,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['ex_date'] = Variable<int>(ex_date);
    map['amount_per_share'] = Variable<double>(amount_per_share);
    return map;
  }

  DividendEventsCompanion toCompanion(bool nullToAbsent) {
    return DividendEventsCompanion(
      symbol: Value(symbol),
      ex_date: Value(ex_date),
      amount_per_share: Value(amount_per_share),
    );
  }

  factory DividendEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DividendEvent(
      symbol: serializer.fromJson<String>(json['symbol']),
      ex_date: serializer.fromJson<int>(json['ex_date']),
      amount_per_share: serializer.fromJson<double>(json['amount_per_share']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'ex_date': serializer.toJson<int>(ex_date),
      'amount_per_share': serializer.toJson<double>(amount_per_share),
    };
  }

  DividendEvent copyWith({
    String? symbol,
    int? ex_date,
    double? amount_per_share,
  }) => DividendEvent(
    symbol: symbol ?? this.symbol,
    ex_date: ex_date ?? this.ex_date,
    amount_per_share: amount_per_share ?? this.amount_per_share,
  );
  DividendEvent copyWithCompanion(DividendEventsCompanion data) {
    return DividendEvent(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      ex_date: data.ex_date.present ? data.ex_date.value : this.ex_date,
      amount_per_share: data.amount_per_share.present
          ? data.amount_per_share.value
          : this.amount_per_share,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DividendEvent(')
          ..write('symbol: $symbol, ')
          ..write('ex_date: $ex_date, ')
          ..write('amount_per_share: $amount_per_share')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, ex_date, amount_per_share);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DividendEvent &&
          other.symbol == this.symbol &&
          other.ex_date == this.ex_date &&
          other.amount_per_share == this.amount_per_share);
}

class DividendEventsCompanion extends UpdateCompanion<DividendEvent> {
  final Value<String> symbol;
  final Value<int> ex_date;
  final Value<double> amount_per_share;
  final Value<int> rowid;
  const DividendEventsCompanion({
    this.symbol = const Value.absent(),
    this.ex_date = const Value.absent(),
    this.amount_per_share = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DividendEventsCompanion.insert({
    required String symbol,
    required int ex_date,
    required double amount_per_share,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       ex_date = Value(ex_date),
       amount_per_share = Value(amount_per_share);
  static Insertable<DividendEvent> custom({
    Expression<String>? symbol,
    Expression<int>? ex_date,
    Expression<double>? amount_per_share,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (ex_date != null) 'ex_date': ex_date,
      if (amount_per_share != null) 'amount_per_share': amount_per_share,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DividendEventsCompanion copyWith({
    Value<String>? symbol,
    Value<int>? ex_date,
    Value<double>? amount_per_share,
    Value<int>? rowid,
  }) {
    return DividendEventsCompanion(
      symbol: symbol ?? this.symbol,
      ex_date: ex_date ?? this.ex_date,
      amount_per_share: amount_per_share ?? this.amount_per_share,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (ex_date.present) {
      map['ex_date'] = Variable<int>(ex_date.value);
    }
    if (amount_per_share.present) {
      map['amount_per_share'] = Variable<double>(amount_per_share.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DividendEventsCompanion(')
          ..write('symbol: $symbol, ')
          ..write('ex_date: $ex_date, ')
          ..write('amount_per_share: $amount_per_share, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchlistSymbolsTable extends WatchlistSymbols
    with TableInfo<$WatchlistSymbolsTable, WatchlistSymbol> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistSymbolsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _added_atMeta = const VerificationMeta(
    'added_at',
  );
  @override
  late final GeneratedColumn<int> added_at = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, name, added_at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_symbols';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistSymbol> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _added_atMeta,
        added_at.isAcceptableOrUnknown(data['added_at']!, _added_atMeta),
      );
    } else if (isInserting) {
      context.missing(_added_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  WatchlistSymbol map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistSymbol(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      added_at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $WatchlistSymbolsTable createAlias(String alias) {
    return $WatchlistSymbolsTable(attachedDatabase, alias);
  }
}

class WatchlistSymbol extends DataClass implements Insertable<WatchlistSymbol> {
  final String symbol;
  final String name;
  final int added_at;
  const WatchlistSymbol({
    required this.symbol,
    required this.name,
    required this.added_at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['added_at'] = Variable<int>(added_at);
    return map;
  }

  WatchlistSymbolsCompanion toCompanion(bool nullToAbsent) {
    return WatchlistSymbolsCompanion(
      symbol: Value(symbol),
      name: Value(name),
      added_at: Value(added_at),
    );
  }

  factory WatchlistSymbol.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistSymbol(
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      added_at: serializer.fromJson<int>(json['added_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'added_at': serializer.toJson<int>(added_at),
    };
  }

  WatchlistSymbol copyWith({String? symbol, String? name, int? added_at}) =>
      WatchlistSymbol(
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        added_at: added_at ?? this.added_at,
      );
  WatchlistSymbol copyWithCompanion(WatchlistSymbolsCompanion data) {
    return WatchlistSymbol(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      added_at: data.added_at.present ? data.added_at.value : this.added_at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistSymbol(')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('added_at: $added_at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, name, added_at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistSymbol &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.added_at == this.added_at);
}

class WatchlistSymbolsCompanion extends UpdateCompanion<WatchlistSymbol> {
  final Value<String> symbol;
  final Value<String> name;
  final Value<int> added_at;
  final Value<int> rowid;
  const WatchlistSymbolsCompanion({
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.added_at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistSymbolsCompanion.insert({
    required String symbol,
    required String name,
    required int added_at,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       name = Value(name),
       added_at = Value(added_at);
  static Insertable<WatchlistSymbol> custom({
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<int>? added_at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (added_at != null) 'added_at': added_at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistSymbolsCompanion copyWith({
    Value<String>? symbol,
    Value<String>? name,
    Value<int>? added_at,
    Value<int>? rowid,
  }) {
    return WatchlistSymbolsCompanion(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      added_at: added_at ?? this.added_at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (added_at.present) {
      map['added_at'] = Variable<int>(added_at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistSymbolsCompanion(')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('added_at: $added_at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StockTransactionsTable stockTransactions =
      $StockTransactionsTable(this);
  late final $QuoteCacheTable quoteCache = $QuoteCacheTable(this);
  late final $HistoricalPricesTable historicalPrices = $HistoricalPricesTable(
    this,
  );
  late final $DividendEventsTable dividendEvents = $DividendEventsTable(this);
  late final $WatchlistSymbolsTable watchlistSymbols = $WatchlistSymbolsTable(
    this,
  );
  late final TransactionDao transactionDao = TransactionDao(
    this as AppDatabase,
  );
  late final QuoteCacheDao quoteCacheDao = QuoteCacheDao(this as AppDatabase);
  late final HistoricalPriceDao historicalPriceDao = HistoricalPriceDao(
    this as AppDatabase,
  );
  late final DividendDao dividendDao = DividendDao(this as AppDatabase);
  late final WatchlistDao watchlistDao = WatchlistDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stockTransactions,
    quoteCache,
    historicalPrices,
    dividendEvents,
    watchlistSymbols,
  ];
}

typedef $$StockTransactionsTableCreateCompanionBuilder =
    StockTransactionsCompanion Function({
      Value<int> id,
      required String symbol,
      required int trade_date,
      required double purchase_price,
      required double quantity,
      required String transaction_type,
      Value<double?> commission,
      Value<String?> comment,
    });
typedef $$StockTransactionsTableUpdateCompanionBuilder =
    StockTransactionsCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<int> trade_date,
      Value<double> purchase_price,
      Value<double> quantity,
      Value<String> transaction_type,
      Value<double?> commission,
      Value<String?> comment,
    });

class $$StockTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trade_date => $composableBuilder(
    column: $table.trade_date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchase_price => $composableBuilder(
    column: $table.purchase_price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transaction_type => $composableBuilder(
    column: $table.transaction_type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trade_date => $composableBuilder(
    column: $table.trade_date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchase_price => $composableBuilder(
    column: $table.purchase_price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transaction_type => $composableBuilder(
    column: $table.transaction_type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get trade_date => $composableBuilder(
    column: $table.trade_date,
    builder: (column) => column,
  );

  GeneratedColumn<double> get purchase_price => $composableBuilder(
    column: $table.purchase_price,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get transaction_type => $composableBuilder(
    column: $table.transaction_type,
    builder: (column) => column,
  );

  GeneratedColumn<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);
}

class $$StockTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransactionRow,
          $$StockTransactionsTableFilterComposer,
          $$StockTransactionsTableOrderingComposer,
          $$StockTransactionsTableAnnotationComposer,
          $$StockTransactionsTableCreateCompanionBuilder,
          $$StockTransactionsTableUpdateCompanionBuilder,
          (
            StockTransactionRow,
            BaseReferences<
              _$AppDatabase,
              $StockTransactionsTable,
              StockTransactionRow
            >,
          ),
          StockTransactionRow,
          PrefetchHooks Function()
        > {
  $$StockTransactionsTableTableManager(
    _$AppDatabase db,
    $StockTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<int> trade_date = const Value.absent(),
                Value<double> purchase_price = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> transaction_type = const Value.absent(),
                Value<double?> commission = const Value.absent(),
                Value<String?> comment = const Value.absent(),
              }) => StockTransactionsCompanion(
                id: id,
                symbol: symbol,
                trade_date: trade_date,
                purchase_price: purchase_price,
                quantity: quantity,
                transaction_type: transaction_type,
                commission: commission,
                comment: comment,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                required int trade_date,
                required double purchase_price,
                required double quantity,
                required String transaction_type,
                Value<double?> commission = const Value.absent(),
                Value<String?> comment = const Value.absent(),
              }) => StockTransactionsCompanion.insert(
                id: id,
                symbol: symbol,
                trade_date: trade_date,
                purchase_price: purchase_price,
                quantity: quantity,
                transaction_type: transaction_type,
                commission: commission,
                comment: comment,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockTransactionsTable,
      StockTransactionRow,
      $$StockTransactionsTableFilterComposer,
      $$StockTransactionsTableOrderingComposer,
      $$StockTransactionsTableAnnotationComposer,
      $$StockTransactionsTableCreateCompanionBuilder,
      $$StockTransactionsTableUpdateCompanionBuilder,
      (
        StockTransactionRow,
        BaseReferences<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransactionRow
        >,
      ),
      StockTransactionRow,
      PrefetchHooks Function()
    >;
typedef $$QuoteCacheTableCreateCompanionBuilder =
    QuoteCacheCompanion Function({
      required String symbol,
      Value<double?> regular_price,
      Value<int?> regular_time,
      Value<double?> pre_price,
      Value<int?> pre_time,
      Value<double?> post_price,
      Value<int?> post_time,
      Value<double?> previous_close,
      Value<String?> market_state,
      required int fetched_at,
      Value<int> rowid,
    });
typedef $$QuoteCacheTableUpdateCompanionBuilder =
    QuoteCacheCompanion Function({
      Value<String> symbol,
      Value<double?> regular_price,
      Value<int?> regular_time,
      Value<double?> pre_price,
      Value<int?> pre_time,
      Value<double?> post_price,
      Value<int?> post_time,
      Value<double?> previous_close,
      Value<String?> market_state,
      Value<int> fetched_at,
      Value<int> rowid,
    });

class $$QuoteCacheTableFilterComposer
    extends Composer<_$AppDatabase, $QuoteCacheTable> {
  $$QuoteCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get regular_price => $composableBuilder(
    column: $table.regular_price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regular_time => $composableBuilder(
    column: $table.regular_time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pre_price => $composableBuilder(
    column: $table.pre_price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pre_time => $composableBuilder(
    column: $table.pre_time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get post_price => $composableBuilder(
    column: $table.post_price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get post_time => $composableBuilder(
    column: $table.post_time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get previous_close => $composableBuilder(
    column: $table.previous_close,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get market_state => $composableBuilder(
    column: $table.market_state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetched_at => $composableBuilder(
    column: $table.fetched_at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuoteCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $QuoteCacheTable> {
  $$QuoteCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get regular_price => $composableBuilder(
    column: $table.regular_price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regular_time => $composableBuilder(
    column: $table.regular_time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pre_price => $composableBuilder(
    column: $table.pre_price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pre_time => $composableBuilder(
    column: $table.pre_time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get post_price => $composableBuilder(
    column: $table.post_price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get post_time => $composableBuilder(
    column: $table.post_time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get previous_close => $composableBuilder(
    column: $table.previous_close,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get market_state => $composableBuilder(
    column: $table.market_state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetched_at => $composableBuilder(
    column: $table.fetched_at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuoteCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuoteCacheTable> {
  $$QuoteCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<double> get regular_price => $composableBuilder(
    column: $table.regular_price,
    builder: (column) => column,
  );

  GeneratedColumn<int> get regular_time => $composableBuilder(
    column: $table.regular_time,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pre_price =>
      $composableBuilder(column: $table.pre_price, builder: (column) => column);

  GeneratedColumn<int> get pre_time =>
      $composableBuilder(column: $table.pre_time, builder: (column) => column);

  GeneratedColumn<double> get post_price => $composableBuilder(
    column: $table.post_price,
    builder: (column) => column,
  );

  GeneratedColumn<int> get post_time =>
      $composableBuilder(column: $table.post_time, builder: (column) => column);

  GeneratedColumn<double> get previous_close => $composableBuilder(
    column: $table.previous_close,
    builder: (column) => column,
  );

  GeneratedColumn<String> get market_state => $composableBuilder(
    column: $table.market_state,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetched_at => $composableBuilder(
    column: $table.fetched_at,
    builder: (column) => column,
  );
}

class $$QuoteCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuoteCacheTable,
          QuoteCacheData,
          $$QuoteCacheTableFilterComposer,
          $$QuoteCacheTableOrderingComposer,
          $$QuoteCacheTableAnnotationComposer,
          $$QuoteCacheTableCreateCompanionBuilder,
          $$QuoteCacheTableUpdateCompanionBuilder,
          (
            QuoteCacheData,
            BaseReferences<_$AppDatabase, $QuoteCacheTable, QuoteCacheData>,
          ),
          QuoteCacheData,
          PrefetchHooks Function()
        > {
  $$QuoteCacheTableTableManager(_$AppDatabase db, $QuoteCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuoteCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuoteCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuoteCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<double?> regular_price = const Value.absent(),
                Value<int?> regular_time = const Value.absent(),
                Value<double?> pre_price = const Value.absent(),
                Value<int?> pre_time = const Value.absent(),
                Value<double?> post_price = const Value.absent(),
                Value<int?> post_time = const Value.absent(),
                Value<double?> previous_close = const Value.absent(),
                Value<String?> market_state = const Value.absent(),
                Value<int> fetched_at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuoteCacheCompanion(
                symbol: symbol,
                regular_price: regular_price,
                regular_time: regular_time,
                pre_price: pre_price,
                pre_time: pre_time,
                post_price: post_price,
                post_time: post_time,
                previous_close: previous_close,
                market_state: market_state,
                fetched_at: fetched_at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                Value<double?> regular_price = const Value.absent(),
                Value<int?> regular_time = const Value.absent(),
                Value<double?> pre_price = const Value.absent(),
                Value<int?> pre_time = const Value.absent(),
                Value<double?> post_price = const Value.absent(),
                Value<int?> post_time = const Value.absent(),
                Value<double?> previous_close = const Value.absent(),
                Value<String?> market_state = const Value.absent(),
                required int fetched_at,
                Value<int> rowid = const Value.absent(),
              }) => QuoteCacheCompanion.insert(
                symbol: symbol,
                regular_price: regular_price,
                regular_time: regular_time,
                pre_price: pre_price,
                pre_time: pre_time,
                post_price: post_price,
                post_time: post_time,
                previous_close: previous_close,
                market_state: market_state,
                fetched_at: fetched_at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuoteCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuoteCacheTable,
      QuoteCacheData,
      $$QuoteCacheTableFilterComposer,
      $$QuoteCacheTableOrderingComposer,
      $$QuoteCacheTableAnnotationComposer,
      $$QuoteCacheTableCreateCompanionBuilder,
      $$QuoteCacheTableUpdateCompanionBuilder,
      (
        QuoteCacheData,
        BaseReferences<_$AppDatabase, $QuoteCacheTable, QuoteCacheData>,
      ),
      QuoteCacheData,
      PrefetchHooks Function()
    >;
typedef $$HistoricalPricesTableCreateCompanionBuilder =
    HistoricalPricesCompanion Function({
      required String symbol,
      required int date,
      required double close_price,
      Value<int> rowid,
    });
typedef $$HistoricalPricesTableUpdateCompanionBuilder =
    HistoricalPricesCompanion Function({
      Value<String> symbol,
      Value<int> date,
      Value<double> close_price,
      Value<int> rowid,
    });

class $$HistoricalPricesTableFilterComposer
    extends Composer<_$AppDatabase, $HistoricalPricesTable> {
  $$HistoricalPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get close_price => $composableBuilder(
    column: $table.close_price,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoricalPricesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoricalPricesTable> {
  $$HistoricalPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get close_price => $composableBuilder(
    column: $table.close_price,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoricalPricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoricalPricesTable> {
  $$HistoricalPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get close_price => $composableBuilder(
    column: $table.close_price,
    builder: (column) => column,
  );
}

class $$HistoricalPricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoricalPricesTable,
          HistoricalPrice,
          $$HistoricalPricesTableFilterComposer,
          $$HistoricalPricesTableOrderingComposer,
          $$HistoricalPricesTableAnnotationComposer,
          $$HistoricalPricesTableCreateCompanionBuilder,
          $$HistoricalPricesTableUpdateCompanionBuilder,
          (
            HistoricalPrice,
            BaseReferences<
              _$AppDatabase,
              $HistoricalPricesTable,
              HistoricalPrice
            >,
          ),
          HistoricalPrice,
          PrefetchHooks Function()
        > {
  $$HistoricalPricesTableTableManager(
    _$AppDatabase db,
    $HistoricalPricesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoricalPricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoricalPricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoricalPricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<double> close_price = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoricalPricesCompanion(
                symbol: symbol,
                date: date,
                close_price: close_price,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required int date,
                required double close_price,
                Value<int> rowid = const Value.absent(),
              }) => HistoricalPricesCompanion.insert(
                symbol: symbol,
                date: date,
                close_price: close_price,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoricalPricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoricalPricesTable,
      HistoricalPrice,
      $$HistoricalPricesTableFilterComposer,
      $$HistoricalPricesTableOrderingComposer,
      $$HistoricalPricesTableAnnotationComposer,
      $$HistoricalPricesTableCreateCompanionBuilder,
      $$HistoricalPricesTableUpdateCompanionBuilder,
      (
        HistoricalPrice,
        BaseReferences<_$AppDatabase, $HistoricalPricesTable, HistoricalPrice>,
      ),
      HistoricalPrice,
      PrefetchHooks Function()
    >;
typedef $$DividendEventsTableCreateCompanionBuilder =
    DividendEventsCompanion Function({
      required String symbol,
      required int ex_date,
      required double amount_per_share,
      Value<int> rowid,
    });
typedef $$DividendEventsTableUpdateCompanionBuilder =
    DividendEventsCompanion Function({
      Value<String> symbol,
      Value<int> ex_date,
      Value<double> amount_per_share,
      Value<int> rowid,
    });

class $$DividendEventsTableFilterComposer
    extends Composer<_$AppDatabase, $DividendEventsTable> {
  $$DividendEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ex_date => $composableBuilder(
    column: $table.ex_date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount_per_share => $composableBuilder(
    column: $table.amount_per_share,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DividendEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $DividendEventsTable> {
  $$DividendEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ex_date => $composableBuilder(
    column: $table.ex_date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount_per_share => $composableBuilder(
    column: $table.amount_per_share,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DividendEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DividendEventsTable> {
  $$DividendEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get ex_date =>
      $composableBuilder(column: $table.ex_date, builder: (column) => column);

  GeneratedColumn<double> get amount_per_share => $composableBuilder(
    column: $table.amount_per_share,
    builder: (column) => column,
  );
}

class $$DividendEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DividendEventsTable,
          DividendEvent,
          $$DividendEventsTableFilterComposer,
          $$DividendEventsTableOrderingComposer,
          $$DividendEventsTableAnnotationComposer,
          $$DividendEventsTableCreateCompanionBuilder,
          $$DividendEventsTableUpdateCompanionBuilder,
          (
            DividendEvent,
            BaseReferences<_$AppDatabase, $DividendEventsTable, DividendEvent>,
          ),
          DividendEvent,
          PrefetchHooks Function()
        > {
  $$DividendEventsTableTableManager(
    _$AppDatabase db,
    $DividendEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DividendEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DividendEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DividendEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<int> ex_date = const Value.absent(),
                Value<double> amount_per_share = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DividendEventsCompanion(
                symbol: symbol,
                ex_date: ex_date,
                amount_per_share: amount_per_share,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required int ex_date,
                required double amount_per_share,
                Value<int> rowid = const Value.absent(),
              }) => DividendEventsCompanion.insert(
                symbol: symbol,
                ex_date: ex_date,
                amount_per_share: amount_per_share,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DividendEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DividendEventsTable,
      DividendEvent,
      $$DividendEventsTableFilterComposer,
      $$DividendEventsTableOrderingComposer,
      $$DividendEventsTableAnnotationComposer,
      $$DividendEventsTableCreateCompanionBuilder,
      $$DividendEventsTableUpdateCompanionBuilder,
      (
        DividendEvent,
        BaseReferences<_$AppDatabase, $DividendEventsTable, DividendEvent>,
      ),
      DividendEvent,
      PrefetchHooks Function()
    >;
typedef $$WatchlistSymbolsTableCreateCompanionBuilder =
    WatchlistSymbolsCompanion Function({
      required String symbol,
      required String name,
      required int added_at,
      Value<int> rowid,
    });
typedef $$WatchlistSymbolsTableUpdateCompanionBuilder =
    WatchlistSymbolsCompanion Function({
      Value<String> symbol,
      Value<String> name,
      Value<int> added_at,
      Value<int> rowid,
    });

class $$WatchlistSymbolsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistSymbolsTable> {
  $$WatchlistSymbolsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get added_at => $composableBuilder(
    column: $table.added_at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchlistSymbolsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistSymbolsTable> {
  $$WatchlistSymbolsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get added_at => $composableBuilder(
    column: $table.added_at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistSymbolsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistSymbolsTable> {
  $$WatchlistSymbolsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get added_at =>
      $composableBuilder(column: $table.added_at, builder: (column) => column);
}

class $$WatchlistSymbolsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistSymbolsTable,
          WatchlistSymbol,
          $$WatchlistSymbolsTableFilterComposer,
          $$WatchlistSymbolsTableOrderingComposer,
          $$WatchlistSymbolsTableAnnotationComposer,
          $$WatchlistSymbolsTableCreateCompanionBuilder,
          $$WatchlistSymbolsTableUpdateCompanionBuilder,
          (
            WatchlistSymbol,
            BaseReferences<
              _$AppDatabase,
              $WatchlistSymbolsTable,
              WatchlistSymbol
            >,
          ),
          WatchlistSymbol,
          PrefetchHooks Function()
        > {
  $$WatchlistSymbolsTableTableManager(
    _$AppDatabase db,
    $WatchlistSymbolsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistSymbolsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistSymbolsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistSymbolsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> added_at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistSymbolsCompanion(
                symbol: symbol,
                name: name,
                added_at: added_at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required String name,
                required int added_at,
                Value<int> rowid = const Value.absent(),
              }) => WatchlistSymbolsCompanion.insert(
                symbol: symbol,
                name: name,
                added_at: added_at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchlistSymbolsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistSymbolsTable,
      WatchlistSymbol,
      $$WatchlistSymbolsTableFilterComposer,
      $$WatchlistSymbolsTableOrderingComposer,
      $$WatchlistSymbolsTableAnnotationComposer,
      $$WatchlistSymbolsTableCreateCompanionBuilder,
      $$WatchlistSymbolsTableUpdateCompanionBuilder,
      (
        WatchlistSymbol,
        BaseReferences<_$AppDatabase, $WatchlistSymbolsTable, WatchlistSymbol>,
      ),
      WatchlistSymbol,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(_db, _db.stockTransactions);
  $$QuoteCacheTableTableManager get quoteCache =>
      $$QuoteCacheTableTableManager(_db, _db.quoteCache);
  $$HistoricalPricesTableTableManager get historicalPrices =>
      $$HistoricalPricesTableTableManager(_db, _db.historicalPrices);
  $$DividendEventsTableTableManager get dividendEvents =>
      $$DividendEventsTableTableManager(_db, _db.dividendEvents);
  $$WatchlistSymbolsTableTableManager get watchlistSymbols =>
      $$WatchlistSymbolsTableTableManager(_db, _db.watchlistSymbols);
}

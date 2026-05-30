// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FeedItemsTableTable extends FeedItemsTable
    with TableInfo<$FeedItemsTableTable, FeedItemsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, position, json, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_items_table';
  @override
  VerificationContext validateIntegrity(Insertable<FeedItemsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeedItemsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedItemsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $FeedItemsTableTable createAlias(String alias) {
    return $FeedItemsTableTable(attachedDatabase, alias);
  }
}

class FeedItemsTableData extends DataClass
    implements Insertable<FeedItemsTableData> {
  final int id;
  final int position;
  final String json;
  final int cachedAt;
  const FeedItemsTableData(
      {required this.id,
      required this.position,
      required this.json,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['position'] = Variable<int>(position);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  FeedItemsTableCompanion toCompanion(bool nullToAbsent) {
    return FeedItemsTableCompanion(
      id: Value(id),
      position: Value(position),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory FeedItemsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedItemsTableData(
      id: serializer.fromJson<int>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'position': serializer.toJson<int>(position),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  FeedItemsTableData copyWith(
          {int? id, int? position, String? json, int? cachedAt}) =>
      FeedItemsTableData(
        id: id ?? this.id,
        position: position ?? this.position,
        json: json ?? this.json,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  FeedItemsTableData copyWithCompanion(FeedItemsTableCompanion data) {
    return FeedItemsTableData(
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedItemsTableData(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, position, json, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedItemsTableData &&
          other.id == this.id &&
          other.position == this.position &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class FeedItemsTableCompanion extends UpdateCompanion<FeedItemsTableData> {
  final Value<int> id;
  final Value<int> position;
  final Value<String> json;
  final Value<int> cachedAt;
  const FeedItemsTableCompanion({
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  FeedItemsTableCompanion.insert({
    this.id = const Value.absent(),
    required int position,
    required String json,
    required int cachedAt,
  })  : position = Value(position),
        json = Value(json),
        cachedAt = Value(cachedAt);
  static Insertable<FeedItemsTableData> custom({
    Expression<int>? id,
    Expression<int>? position,
    Expression<String>? json,
    Expression<int>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  FeedItemsTableCompanion copyWith(
      {Value<int>? id,
      Value<int>? position,
      Value<String>? json,
      Value<int>? cachedAt}) {
    return FeedItemsTableCompanion(
      id: id ?? this.id,
      position: position ?? this.position,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $FeedProgressTableTable extends FeedProgressTable
    with TableInfo<$FeedProgressTableTable, FeedProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta =
      const VerificationMeta('episodeId');
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
      'episode_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [episodeId, positionSeconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_progress_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<FeedProgressTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(_episodeIdMeta,
          episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta));
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  FeedProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedProgressTableData(
      episodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode_id'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
    );
  }

  @override
  $FeedProgressTableTable createAlias(String alias) {
    return $FeedProgressTableTable(attachedDatabase, alias);
  }
}

class FeedProgressTableData extends DataClass
    implements Insertable<FeedProgressTableData> {
  final int episodeId;
  final int positionSeconds;
  const FeedProgressTableData(
      {required this.episodeId, required this.positionSeconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['position_seconds'] = Variable<int>(positionSeconds);
    return map;
  }

  FeedProgressTableCompanion toCompanion(bool nullToAbsent) {
    return FeedProgressTableCompanion(
      episodeId: Value(episodeId),
      positionSeconds: Value(positionSeconds),
    );
  }

  factory FeedProgressTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedProgressTableData(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
    };
  }

  FeedProgressTableData copyWith({int? episodeId, int? positionSeconds}) =>
      FeedProgressTableData(
        episodeId: episodeId ?? this.episodeId,
        positionSeconds: positionSeconds ?? this.positionSeconds,
      );
  FeedProgressTableData copyWithCompanion(FeedProgressTableCompanion data) {
    return FeedProgressTableData(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedProgressTableData(')
          ..write('episodeId: $episodeId, ')
          ..write('positionSeconds: $positionSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(episodeId, positionSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedProgressTableData &&
          other.episodeId == this.episodeId &&
          other.positionSeconds == this.positionSeconds);
}

class FeedProgressTableCompanion
    extends UpdateCompanion<FeedProgressTableData> {
  final Value<int> episodeId;
  final Value<int> positionSeconds;
  const FeedProgressTableCompanion({
    this.episodeId = const Value.absent(),
    this.positionSeconds = const Value.absent(),
  });
  FeedProgressTableCompanion.insert({
    this.episodeId = const Value.absent(),
    required int positionSeconds,
  }) : positionSeconds = Value(positionSeconds);
  static Insertable<FeedProgressTableData> custom({
    Expression<int>? episodeId,
    Expression<int>? positionSeconds,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
    });
  }

  FeedProgressTableCompanion copyWith(
      {Value<int>? episodeId, Value<int>? positionSeconds}) {
    return FeedProgressTableCompanion(
      episodeId: episodeId ?? this.episodeId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedProgressTableCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('positionSeconds: $positionSeconds')
          ..write(')'))
        .toString();
  }
}

class $FeedMetaTableTable extends FeedMetaTable
    with TableInfo<$FeedMetaTableTable, FeedMetaTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedMetaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_meta_table';
  @override
  VerificationContext validateIntegrity(Insertable<FeedMetaTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  FeedMetaTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedMetaTableData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $FeedMetaTableTable createAlias(String alias) {
    return $FeedMetaTableTable(attachedDatabase, alias);
  }
}

class FeedMetaTableData extends DataClass
    implements Insertable<FeedMetaTableData> {
  final String key;
  final String value;
  const FeedMetaTableData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  FeedMetaTableCompanion toCompanion(bool nullToAbsent) {
    return FeedMetaTableCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory FeedMetaTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedMetaTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  FeedMetaTableData copyWith({String? key, String? value}) => FeedMetaTableData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  FeedMetaTableData copyWithCompanion(FeedMetaTableCompanion data) {
    return FeedMetaTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedMetaTableData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedMetaTableData &&
          other.key == this.key &&
          other.value == this.value);
}

class FeedMetaTableCompanion extends UpdateCompanion<FeedMetaTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const FeedMetaTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedMetaTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<FeedMetaTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedMetaTableCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return FeedMetaTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedMetaTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HomeCacheTableTable extends HomeCacheTable
    with TableInfo<$HomeCacheTableTable, HomeCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'home_cache_table';
  @override
  VerificationContext validateIntegrity(Insertable<HomeCacheTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HomeCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HomeCacheTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $HomeCacheTableTable createAlias(String alias) {
    return $HomeCacheTableTable(attachedDatabase, alias);
  }
}

class HomeCacheTableData extends DataClass
    implements Insertable<HomeCacheTableData> {
  final int id;
  final String json;
  final int cachedAt;
  const HomeCacheTableData(
      {required this.id, required this.json, required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  HomeCacheTableCompanion toCompanion(bool nullToAbsent) {
    return HomeCacheTableCompanion(
      id: Value(id),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory HomeCacheTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HomeCacheTableData(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  HomeCacheTableData copyWith({int? id, String? json, int? cachedAt}) =>
      HomeCacheTableData(
        id: id ?? this.id,
        json: json ?? this.json,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  HomeCacheTableData copyWithCompanion(HomeCacheTableCompanion data) {
    return HomeCacheTableData(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HomeCacheTableData(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HomeCacheTableData &&
          other.id == this.id &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class HomeCacheTableCompanion extends UpdateCompanion<HomeCacheTableData> {
  final Value<int> id;
  final Value<String> json;
  final Value<int> cachedAt;
  const HomeCacheTableCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  HomeCacheTableCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required int cachedAt,
  })  : json = Value(json),
        cachedAt = Value(cachedAt);
  static Insertable<HomeCacheTableData> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<int>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  HomeCacheTableCompanion copyWith(
      {Value<int>? id, Value<String>? json, Value<int>? cachedAt}) {
    return HomeCacheTableCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $ShopCacheTableTable extends ShopCacheTable
    with TableInfo<$ShopCacheTableTable, ShopCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shop_cache_table';
  @override
  VerificationContext validateIntegrity(Insertable<ShopCacheTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShopCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopCacheTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $ShopCacheTableTable createAlias(String alias) {
    return $ShopCacheTableTable(attachedDatabase, alias);
  }
}

class ShopCacheTableData extends DataClass
    implements Insertable<ShopCacheTableData> {
  final int id;
  final String json;
  final int cachedAt;
  const ShopCacheTableData(
      {required this.id, required this.json, required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  ShopCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ShopCacheTableCompanion(
      id: Value(id),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory ShopCacheTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopCacheTableData(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  ShopCacheTableData copyWith({int? id, String? json, int? cachedAt}) =>
      ShopCacheTableData(
        id: id ?? this.id,
        json: json ?? this.json,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  ShopCacheTableData copyWithCompanion(ShopCacheTableCompanion data) {
    return ShopCacheTableData(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopCacheTableData(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopCacheTableData &&
          other.id == this.id &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class ShopCacheTableCompanion extends UpdateCompanion<ShopCacheTableData> {
  final Value<int> id;
  final Value<String> json;
  final Value<int> cachedAt;
  const ShopCacheTableCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  ShopCacheTableCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required int cachedAt,
  })  : json = Value(json),
        cachedAt = Value(cachedAt);
  static Insertable<ShopCacheTableData> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<int>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  ShopCacheTableCompanion copyWith(
      {Value<int>? id, Value<String>? json, Value<int>? cachedAt}) {
    return ShopCacheTableCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FeedItemsTableTable feedItemsTable = $FeedItemsTableTable(this);
  late final $FeedProgressTableTable feedProgressTable =
      $FeedProgressTableTable(this);
  late final $FeedMetaTableTable feedMetaTable = $FeedMetaTableTable(this);
  late final $HomeCacheTableTable homeCacheTable = $HomeCacheTableTable(this);
  late final $ShopCacheTableTable shopCacheTable = $ShopCacheTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        feedItemsTable,
        feedProgressTable,
        feedMetaTable,
        homeCacheTable,
        shopCacheTable
      ];
}

typedef $$FeedItemsTableTableCreateCompanionBuilder = FeedItemsTableCompanion
    Function({
  Value<int> id,
  required int position,
  required String json,
  required int cachedAt,
});
typedef $$FeedItemsTableTableUpdateCompanionBuilder = FeedItemsTableCompanion
    Function({
  Value<int> id,
  Value<int> position,
  Value<String> json,
  Value<int> cachedAt,
});

class $$FeedItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeedItemsTableTable> {
  $$FeedItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$FeedItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedItemsTableTable> {
  $$FeedItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$FeedItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedItemsTableTable> {
  $$FeedItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$FeedItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedItemsTableTable,
    FeedItemsTableData,
    $$FeedItemsTableTableFilterComposer,
    $$FeedItemsTableTableOrderingComposer,
    $$FeedItemsTableTableAnnotationComposer,
    $$FeedItemsTableTableCreateCompanionBuilder,
    $$FeedItemsTableTableUpdateCompanionBuilder,
    (
      FeedItemsTableData,
      BaseReferences<_$AppDatabase, $FeedItemsTableTable, FeedItemsTableData>
    ),
    FeedItemsTableData,
    PrefetchHooks Function()> {
  $$FeedItemsTableTableTableManager(
      _$AppDatabase db, $FeedItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
          }) =>
              FeedItemsTableCompanion(
            id: id,
            position: position,
            json: json,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int position,
            required String json,
            required int cachedAt,
          }) =>
              FeedItemsTableCompanion.insert(
            id: id,
            position: position,
            json: json,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeedItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedItemsTableTable,
    FeedItemsTableData,
    $$FeedItemsTableTableFilterComposer,
    $$FeedItemsTableTableOrderingComposer,
    $$FeedItemsTableTableAnnotationComposer,
    $$FeedItemsTableTableCreateCompanionBuilder,
    $$FeedItemsTableTableUpdateCompanionBuilder,
    (
      FeedItemsTableData,
      BaseReferences<_$AppDatabase, $FeedItemsTableTable, FeedItemsTableData>
    ),
    FeedItemsTableData,
    PrefetchHooks Function()>;
typedef $$FeedProgressTableTableCreateCompanionBuilder
    = FeedProgressTableCompanion Function({
  Value<int> episodeId,
  required int positionSeconds,
});
typedef $$FeedProgressTableTableUpdateCompanionBuilder
    = FeedProgressTableCompanion Function({
  Value<int> episodeId,
  Value<int> positionSeconds,
});

class $$FeedProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeedProgressTableTable> {
  $$FeedProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get episodeId => $composableBuilder(
      column: $table.episodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));
}

class $$FeedProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedProgressTableTable> {
  $$FeedProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get episodeId => $composableBuilder(
      column: $table.episodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));
}

class $$FeedProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedProgressTableTable> {
  $$FeedProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);
}

class $$FeedProgressTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedProgressTableTable,
    FeedProgressTableData,
    $$FeedProgressTableTableFilterComposer,
    $$FeedProgressTableTableOrderingComposer,
    $$FeedProgressTableTableAnnotationComposer,
    $$FeedProgressTableTableCreateCompanionBuilder,
    $$FeedProgressTableTableUpdateCompanionBuilder,
    (
      FeedProgressTableData,
      BaseReferences<_$AppDatabase, $FeedProgressTableTable,
          FeedProgressTableData>
    ),
    FeedProgressTableData,
    PrefetchHooks Function()> {
  $$FeedProgressTableTableTableManager(
      _$AppDatabase db, $FeedProgressTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedProgressTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> episodeId = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
          }) =>
              FeedProgressTableCompanion(
            episodeId: episodeId,
            positionSeconds: positionSeconds,
          ),
          createCompanionCallback: ({
            Value<int> episodeId = const Value.absent(),
            required int positionSeconds,
          }) =>
              FeedProgressTableCompanion.insert(
            episodeId: episodeId,
            positionSeconds: positionSeconds,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeedProgressTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedProgressTableTable,
    FeedProgressTableData,
    $$FeedProgressTableTableFilterComposer,
    $$FeedProgressTableTableOrderingComposer,
    $$FeedProgressTableTableAnnotationComposer,
    $$FeedProgressTableTableCreateCompanionBuilder,
    $$FeedProgressTableTableUpdateCompanionBuilder,
    (
      FeedProgressTableData,
      BaseReferences<_$AppDatabase, $FeedProgressTableTable,
          FeedProgressTableData>
    ),
    FeedProgressTableData,
    PrefetchHooks Function()>;
typedef $$FeedMetaTableTableCreateCompanionBuilder = FeedMetaTableCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$FeedMetaTableTableUpdateCompanionBuilder = FeedMetaTableCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$FeedMetaTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeedMetaTableTable> {
  $$FeedMetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$FeedMetaTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedMetaTableTable> {
  $$FeedMetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$FeedMetaTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedMetaTableTable> {
  $$FeedMetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$FeedMetaTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedMetaTableTable,
    FeedMetaTableData,
    $$FeedMetaTableTableFilterComposer,
    $$FeedMetaTableTableOrderingComposer,
    $$FeedMetaTableTableAnnotationComposer,
    $$FeedMetaTableTableCreateCompanionBuilder,
    $$FeedMetaTableTableUpdateCompanionBuilder,
    (
      FeedMetaTableData,
      BaseReferences<_$AppDatabase, $FeedMetaTableTable, FeedMetaTableData>
    ),
    FeedMetaTableData,
    PrefetchHooks Function()> {
  $$FeedMetaTableTableTableManager(_$AppDatabase db, $FeedMetaTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedMetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedMetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedMetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedMetaTableCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedMetaTableCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeedMetaTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedMetaTableTable,
    FeedMetaTableData,
    $$FeedMetaTableTableFilterComposer,
    $$FeedMetaTableTableOrderingComposer,
    $$FeedMetaTableTableAnnotationComposer,
    $$FeedMetaTableTableCreateCompanionBuilder,
    $$FeedMetaTableTableUpdateCompanionBuilder,
    (
      FeedMetaTableData,
      BaseReferences<_$AppDatabase, $FeedMetaTableTable, FeedMetaTableData>
    ),
    FeedMetaTableData,
    PrefetchHooks Function()>;
typedef $$HomeCacheTableTableCreateCompanionBuilder = HomeCacheTableCompanion
    Function({
  Value<int> id,
  required String json,
  required int cachedAt,
});
typedef $$HomeCacheTableTableUpdateCompanionBuilder = HomeCacheTableCompanion
    Function({
  Value<int> id,
  Value<String> json,
  Value<int> cachedAt,
});

class $$HomeCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $HomeCacheTableTable> {
  $$HomeCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$HomeCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeCacheTableTable> {
  $$HomeCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$HomeCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeCacheTableTable> {
  $$HomeCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$HomeCacheTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HomeCacheTableTable,
    HomeCacheTableData,
    $$HomeCacheTableTableFilterComposer,
    $$HomeCacheTableTableOrderingComposer,
    $$HomeCacheTableTableAnnotationComposer,
    $$HomeCacheTableTableCreateCompanionBuilder,
    $$HomeCacheTableTableUpdateCompanionBuilder,
    (
      HomeCacheTableData,
      BaseReferences<_$AppDatabase, $HomeCacheTableTable, HomeCacheTableData>
    ),
    HomeCacheTableData,
    PrefetchHooks Function()> {
  $$HomeCacheTableTableTableManager(
      _$AppDatabase db, $HomeCacheTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
          }) =>
              HomeCacheTableCompanion(
            id: id,
            json: json,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required int cachedAt,
          }) =>
              HomeCacheTableCompanion.insert(
            id: id,
            json: json,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HomeCacheTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HomeCacheTableTable,
    HomeCacheTableData,
    $$HomeCacheTableTableFilterComposer,
    $$HomeCacheTableTableOrderingComposer,
    $$HomeCacheTableTableAnnotationComposer,
    $$HomeCacheTableTableCreateCompanionBuilder,
    $$HomeCacheTableTableUpdateCompanionBuilder,
    (
      HomeCacheTableData,
      BaseReferences<_$AppDatabase, $HomeCacheTableTable, HomeCacheTableData>
    ),
    HomeCacheTableData,
    PrefetchHooks Function()>;
typedef $$ShopCacheTableTableCreateCompanionBuilder = ShopCacheTableCompanion
    Function({
  Value<int> id,
  required String json,
  required int cachedAt,
});
typedef $$ShopCacheTableTableUpdateCompanionBuilder = ShopCacheTableCompanion
    Function({
  Value<int> id,
  Value<String> json,
  Value<int> cachedAt,
});

class $$ShopCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ShopCacheTableTable> {
  $$ShopCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$ShopCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ShopCacheTableTable> {
  $$ShopCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$ShopCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShopCacheTableTable> {
  $$ShopCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ShopCacheTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShopCacheTableTable,
    ShopCacheTableData,
    $$ShopCacheTableTableFilterComposer,
    $$ShopCacheTableTableOrderingComposer,
    $$ShopCacheTableTableAnnotationComposer,
    $$ShopCacheTableTableCreateCompanionBuilder,
    $$ShopCacheTableTableUpdateCompanionBuilder,
    (
      ShopCacheTableData,
      BaseReferences<_$AppDatabase, $ShopCacheTableTable, ShopCacheTableData>
    ),
    ShopCacheTableData,
    PrefetchHooks Function()> {
  $$ShopCacheTableTableTableManager(
      _$AppDatabase db, $ShopCacheTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
          }) =>
              ShopCacheTableCompanion(
            id: id,
            json: json,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required int cachedAt,
          }) =>
              ShopCacheTableCompanion.insert(
            id: id,
            json: json,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ShopCacheTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ShopCacheTableTable,
    ShopCacheTableData,
    $$ShopCacheTableTableFilterComposer,
    $$ShopCacheTableTableOrderingComposer,
    $$ShopCacheTableTableAnnotationComposer,
    $$ShopCacheTableTableCreateCompanionBuilder,
    $$ShopCacheTableTableUpdateCompanionBuilder,
    (
      ShopCacheTableData,
      BaseReferences<_$AppDatabase, $ShopCacheTableTable, ShopCacheTableData>
    ),
    ShopCacheTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FeedItemsTableTableTableManager get feedItemsTable =>
      $$FeedItemsTableTableTableManager(_db, _db.feedItemsTable);
  $$FeedProgressTableTableTableManager get feedProgressTable =>
      $$FeedProgressTableTableTableManager(_db, _db.feedProgressTable);
  $$FeedMetaTableTableTableManager get feedMetaTable =>
      $$FeedMetaTableTableTableManager(_db, _db.feedMetaTable);
  $$HomeCacheTableTableTableManager get homeCacheTable =>
      $$HomeCacheTableTableTableManager(_db, _db.homeCacheTable);
  $$ShopCacheTableTableTableManager get shopCacheTable =>
      $$ShopCacheTableTableTableManager(_db, _db.shopCacheTable);
}

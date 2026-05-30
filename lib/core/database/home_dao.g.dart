// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_dao.dart';

// ignore_for_file: type=lint
mixin _$HomeDaoMixin on DatabaseAccessor<AppDatabase> {
  $HomeCacheTableTable get homeCacheTable => attachedDatabase.homeCacheTable;
  HomeDaoManager get managers => HomeDaoManager(this);
}

class HomeDaoManager {
  final _$HomeDaoMixin _db;
  HomeDaoManager(this._db);
  $$HomeCacheTableTableTableManager get homeCacheTable =>
      $$HomeCacheTableTableTableManager(
          _db.attachedDatabase, _db.homeCacheTable);
}

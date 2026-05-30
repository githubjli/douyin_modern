// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_dao.dart';

// ignore_for_file: type=lint
mixin _$ShopDaoMixin on DatabaseAccessor<AppDatabase> {
  $ShopCacheTableTable get shopCacheTable => attachedDatabase.shopCacheTable;
  ShopDaoManager get managers => ShopDaoManager(this);
}

class ShopDaoManager {
  final _$ShopDaoMixin _db;
  ShopDaoManager(this._db);
  $$ShopCacheTableTableTableManager get shopCacheTable =>
      $$ShopCacheTableTableTableManager(
          _db.attachedDatabase, _db.shopCacheTable);
}

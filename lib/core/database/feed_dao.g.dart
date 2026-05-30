// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_dao.dart';

// ignore_for_file: type=lint
mixin _$FeedDaoMixin on DatabaseAccessor<AppDatabase> {
  $FeedItemsTableTable get feedItemsTable => attachedDatabase.feedItemsTable;
  $FeedProgressTableTable get feedProgressTable =>
      attachedDatabase.feedProgressTable;
  $FeedMetaTableTable get feedMetaTable => attachedDatabase.feedMetaTable;
  FeedDaoManager get managers => FeedDaoManager(this);
}

class FeedDaoManager {
  final _$FeedDaoMixin _db;
  FeedDaoManager(this._db);
  $$FeedItemsTableTableTableManager get feedItemsTable =>
      $$FeedItemsTableTableTableManager(
          _db.attachedDatabase, _db.feedItemsTable);
  $$FeedProgressTableTableTableManager get feedProgressTable =>
      $$FeedProgressTableTableTableManager(
          _db.attachedDatabase, _db.feedProgressTable);
  $$FeedMetaTableTableTableManager get feedMetaTable =>
      $$FeedMetaTableTableTableManager(_db.attachedDatabase, _db.feedMetaTable);
}

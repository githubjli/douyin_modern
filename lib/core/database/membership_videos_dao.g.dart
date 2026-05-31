// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'membership_videos_dao.dart';

// ignore_for_file: type=lint
mixin _$MembershipVideosDaoMixin on DatabaseAccessor<AppDatabase> {
  $MembershipVideosCacheTableTable get membershipVideosCacheTable =>
      attachedDatabase.membershipVideosCacheTable;
  MembershipVideosDaoManager get managers => MembershipVideosDaoManager(this);
}

class MembershipVideosDaoManager {
  final _$MembershipVideosDaoMixin _db;
  MembershipVideosDaoManager(this._db);
  $$MembershipVideosCacheTableTableTableManager
      get membershipVideosCacheTable =>
          $$MembershipVideosCacheTableTableTableManager(
              _db.attachedDatabase, _db.membershipVideosCacheTable);
}

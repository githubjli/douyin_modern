import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// One row per cached FeedItem. `position` preserves feed order.
/// `cachedAt` is epoch-ms of the batch that wrote this row.
class FeedItemsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get position => integer()();
  TextColumn get json => text()(); // FeedItem.toJson()
  IntColumn get cachedAt => integer()();
}

/// Per-episode playback progress.
class FeedProgressTable extends Table {
  IntColumn get episodeId => integer()();
  IntColumn get positionSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {episodeId};
}

/// Scalar metadata (last viewed index, etc.).
class FeedMetaTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [FeedItemsTable, FeedProgressTable, FeedMetaTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File(p.join(dir.path, 'meow_media.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

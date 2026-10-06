import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ============================================================================
// Settings Table
// ============================================================================
class SettingsEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get value => text().nullable()();
}

// ============================================================================
// Local Store Video Table (saved videos & history)
// ============================================================================
class LocalStoreVideos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get profileName => text()();
  TextColumn get title => text().nullable()();
  IntColumn get views => integer().nullable()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get uploadedDate => text().nullable()();
  TextColumn get uploaderName => text().nullable()();
  TextColumn get uploaderId => text().nullable()();
  TextColumn get uploaderAvatar => text().nullable()();
  TextColumn get uploaderSubscriberCount => text().nullable()();
  IntColumn get duration => integer().nullable()();
  BoolColumn get uploaderVerified =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isSaved => boolean().withDefault(const Constant(false))();
  BoolColumn get isHistory => boolean().withDefault(const Constant(false))();
  BoolColumn get isLive => boolean().withDefault(const Constant(false))();
  IntColumn get playbackPosition => integer().nullable()();
  DateTimeColumn get time => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {videoId, profileName}
      ];
}

// ============================================================================
// Subscriptions Table
// ============================================================================
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channelId => text()();
  TextColumn get profileName => text()();
  TextColumn get channelName => text()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  TextColumn get avatarUrl => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {channelId, profileName}
      ];
}

// ============================================================================
// Search History Table
// ============================================================================
class SearchHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  TextColumn get profileName => text()();
  DateTimeColumn get searchedAt => dateTime()();
  IntColumn get searchCount => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {query, profileName}
      ];
}

// ============================================================================
// User Interactions Table (for recommendations)
// ============================================================================
class UserInteractions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  IntColumn get interactionType => integer()(); // enum ordinal
  TextColumn get profileName => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  TextColumn get title => text().nullable()();
  TextColumn get channelName => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON array as string

  @override
  List<Set<Column>> get uniqueKeys => [
        {interactionType, entityId, profileName}
      ];
}

// ============================================================================
// User Topic Preferences Table
// ============================================================================
class UserTopicPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get topic => text()();
  TextColumn get profileName => text()();
  RealColumn get relevanceScore => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {topic, profileName}
      ];
}

// ============================================================================
// Download Items Table
// ============================================================================
class DownloadItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get profileName => text()();
  TextColumn get title => text()();
  TextColumn get channelName => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get duration => integer().nullable()();
  TextColumn get videoQuality => text().nullable()();
  TextColumn get audioQuality => text().nullable()();
  IntColumn get downloadType => integer()(); // enum ordinal
  IntColumn get status => integer()(); // enum ordinal
  TextColumn get videoUrl => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get videoFilePath => text().nullable()();
  TextColumn get audioFilePath => text().nullable()();
  TextColumn get outputFilePath => text().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get videoTotalBytes => integer().nullable()();
  IntColumn get audioTotalBytes => integer().nullable()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get videoDownloadedBytes =>
      integer().withDefault(const Constant(0))();
  IntColumn get audioDownloadedBytes =>
      integer().withDefault(const Constant(0))();
  IntColumn get downloadSpeed => integer().withDefault(const Constant(0))();
  IntColumn get etaSeconds => integer().nullable()();
  TextColumn get currentPhase =>
      text().nullable()(); // 'video', 'audio', 'merging'
  TextColumn get errorMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get videoProgress => real().withDefault(const Constant(0.0))();
  RealColumn get audioProgress => real().withDefault(const Constant(0.0))();
}

// ============================================================================
// Database Class
// ============================================================================
@DriftDatabase(tables: [
  SettingsEntries,
  LocalStoreVideos,
  Subscriptions,
  SearchHistoryEntries,
  UserInteractions,
  UserTopicPreferences,
  DownloadItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Add new columns for video+audio tracking
            await m.addColumn(downloadItems, downloadItems.videoTotalBytes);
            await m.addColumn(downloadItems, downloadItems.audioTotalBytes);
            await m.addColumn(
                downloadItems, downloadItems.videoDownloadedBytes);
            await m.addColumn(
                downloadItems, downloadItems.audioDownloadedBytes);
            await m.addColumn(downloadItems, downloadItems.currentPhase);
          }
          if (from < 3) {
            await _createIndexes();
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'fluxtube.db',
      native: DriftNativeOptions(
        databaseDirectory: _databaseDirectory,
        setup: _configureSqlite,
      ),
    );
  }

  /// A kill during a write used to leave a file the next launch could not
  /// open, and the app stayed dead until the data directory was removed.
  /// Only a file sqlite itself calls corrupt is moved aside.
  static void _configureSqlite(CommonDatabase db) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=NORMAL');
  }

  static bool _databaseIsCorrupt(String path) {
    if (!File(path).existsSync()) return false;
    Database? opened;
    try {
      opened = sqlite3.open(path);
      final rows = opened.select('PRAGMA quick_check');
      for (final row in rows) {
        if (row.values.isEmpty) continue;
        if (row.values.first?.toString() != 'ok') return true;
      }
      return false;
    } on SqliteException catch (error) {
      // 11 SQLITE_CORRUPT, 26 SQLITE_NOTADB. A lock or a full disk is not
      // a reason to throw the library away.
      final code = error.resultCode;
      return code == 11 || code == 26;
    } finally {
      opened?.dispose();
    }
  }

  static void _deleteQuarantine(String path) {
    final dir = Directory(p.dirname(path));
    if (!dir.existsSync()) return;
    final prefix = '${p.basename(path)}.bad-';
    var removed = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith(prefix)) continue;
      try {
        entity.deleteSync();
        removed++;
      } catch (_) {}
    }
    if (removed > 0) {
      print('gastube: database quarantine removed count=$removed');
    }
  }

  static void _quarantineDatabase(String path) {
    // Drop older copies first so a corrupt file cannot accumulate.
    _deleteQuarantine(path);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (!file.existsSync()) continue;
      file.renameSync('$path.bad-$stamp$suffix');
    }
    print('gastube: database quarantined path=$path');
  }

  /// One snapshot from the last launch that could still open the file.
  /// Replaced on each healthy start, so a later failure keeps that library
  /// and drops only what was written after it.
  static void _writeBackup(String path) {
    if (!File(path).existsSync()) return;
    final temp = File('$path.bak-new');
    final backup = File('$path.bak');
    Database? opened;
    try {
      if (temp.existsSync()) temp.deleteSync();
      opened = sqlite3.open(path);
      final sqlPath = temp.path.replaceAll("'", "''");
      opened.execute("VACUUM INTO '$sqlPath'");
    } on SqliteException catch (error) {
      print('gastube: database backup skipped code=${error.resultCode}');
      try {
        if (temp.existsSync()) temp.deleteSync();
      } catch (_) {}
      return;
    } finally {
      opened?.dispose();
    }
    try {
      if (backup.existsSync()) backup.deleteSync();
      temp.renameSync(backup.path);
      print('gastube: database backup bytes=${backup.lengthSync()}');
    } catch (error) {
      print('gastube: database backup skipped error=$error');
    }
  }

  static bool _restoreBackup(String path) {
    final backup = File('$path.bak');
    if (!backup.existsSync() || _databaseIsCorrupt(backup.path)) {
      try {
        if (backup.existsSync()) backup.deleteSync();
      } catch (_) {}
      return false;
    }
    final restored = File('$path.restore');
    try {
      if (restored.existsSync()) restored.deleteSync();
      backup.copySync(restored.path);
    } catch (error) {
      print('gastube: database restore failed error=$error');
      return false;
    }
    if (_databaseIsCorrupt(restored.path)) {
      try {
        restored.deleteSync();
        backup.deleteSync();
      } catch (_) {}
      print('gastube: database restore failed path=$path');
      return false;
    }
    _deleteQuarantine(path);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (!file.existsSync()) continue;
      file.renameSync('$path.bad-$stamp$suffix');
    }
    restored.renameSync(path);
    _deleteQuarantine(path);
    print('gastube: database restored path=$path');
    return true;
  }

  /// drift names the file `<name>.sqlite`.
  static Future<Directory> _databaseDirectory() async {
    final support = await persistentAppDirectory();
    final current = File(p.join(support.path, 'fluxtube.db.sqlite'));
    if (_databaseIsCorrupt(current.path)) {
      if (!_restoreBackup(current.path) && current.existsSync()) {
        _quarantineDatabase(current.path);
      }
    }
    if (!await current.exists()) {
      await copyLegacyDocumentFile('fluxtube.db.sqlite', current);
      for (final suffix in ['-wal', '-shm']) {
        await copyLegacyDocumentFile(
          'fluxtube.db.sqlite$suffix',
          File(p.join(support.path, 'fluxtube.db.sqlite$suffix')),
        );
      }
    }
    if (!current.existsSync()) {
      _restoreBackup(current.path);
    }
    if (current.existsSync() && !_databaseIsCorrupt(current.path)) {
      _deleteQuarantine(current.path);
      _writeBackup(current.path);
    }
    return support;
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_store_profile_saved_time '
      'ON local_store_videos(profile_name, is_saved, time DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_store_profile_history_time '
      'ON local_store_videos(profile_name, is_history, time DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_profile '
      'ON subscriptions(profile_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_history_profile_searched_at '
      'ON search_history_entries(profile_name, searched_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_user_interactions_profile_timestamp '
      'ON user_interactions(profile_name, timestamp DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_user_interactions_profile_type_timestamp '
      'ON user_interactions(profile_name, interaction_type, timestamp DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_topic_preferences_profile_relevance '
      'ON user_topic_preferences(profile_name, relevance_score DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_items_profile_created_at '
      'ON download_items(profile_name, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_items_profile_status_created_at '
      'ON download_items(profile_name, status, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_items_profile_video '
      'ON download_items(profile_name, video_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_download_items_status '
      'ON download_items(status)',
    );
  }

  // ============================================================================
  // Settings Operations
  // ============================================================================
  Future<String?> getSetting(String name) async {
    final query = select(settingsEntries)..where((t) => t.name.equals(name));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String settingName, String? value) async {
    await into(settingsEntries).insert(
      SettingsEntriesCompanion.insert(
        name: settingName,
        value: Value(value),
      ),
      onConflict: DoUpdate(
        (old) => SettingsEntriesCompanion(value: Value(value)),
        target: [settingsEntries.name],
      ),
    );
  }

  // ============================================================================
  // Local Store Video Operations
  // ============================================================================
  Future<List<LocalStoreVideo>> getAllVideos(String profileName) async {
    final query = select(localStoreVideos)
      ..where((t) => t.profileName.equals(profileName));
    return query.get();
  }

  Future<List<LocalStoreVideo>> getSavedVideos(String profileName) async {
    final query = select(localStoreVideos)
      ..where(
          (t) => t.profileName.equals(profileName) & t.isSaved.equals(true));
    return query.get();
  }

  Future<List<LocalStoreVideo>> getHistoryVideos(String profileName) async {
    final query = select(localStoreVideos)
      ..where(
          (t) => t.profileName.equals(profileName) & t.isHistory.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.time)]);
    return query.get();
  }

  Future<LocalStoreVideo?> getVideoById(
      String videoId, String profileName) async {
    final query = select(localStoreVideos)
      ..where(
          (t) => t.videoId.equals(videoId) & t.profileName.equals(profileName));
    return query.getSingleOrNull();
  }

  Future<void> upsertVideo(LocalStoreVideosCompanion video) async {
    await into(localStoreVideos).insert(
      video,
      onConflict: DoUpdate(
        (old) => video,
        target: [localStoreVideos.videoId, localStoreVideos.profileName],
      ),
    );
  }

  Future<void> deleteVideo(String videoId, String profileName) async {
    await (delete(localStoreVideos)
          ..where((t) =>
              t.videoId.equals(videoId) & t.profileName.equals(profileName)))
        .go();
  }

  Future<void> deleteAllVideosForProfile(String profileName) async {
    await (delete(localStoreVideos)
          ..where((t) => t.profileName.equals(profileName)))
        .go();
  }

  // ============================================================================
  // Subscription Operations
  // ============================================================================
  Future<List<Subscription>> getAllSubscriptions(String profileName) async {
    final query = select(subscriptions)
      ..where((t) => t.profileName.equals(profileName));
    return query.get();
  }

  Future<Subscription?> getSubscription(
      String channelId, String profileName) async {
    final query = select(subscriptions)
      ..where((t) =>
          t.channelId.equals(channelId) & t.profileName.equals(profileName));
    return query.getSingleOrNull();
  }

  Future<void> upsertSubscription(SubscriptionsCompanion subscription) async {
    await into(subscriptions).insert(
      subscription,
      onConflict: DoUpdate(
        (old) => subscription,
        target: [subscriptions.channelId, subscriptions.profileName],
      ),
    );
  }

  Future<void> deleteSubscription(String channelId, String profileName) async {
    await (delete(subscriptions)
          ..where((t) =>
              t.channelId.equals(channelId) &
              t.profileName.equals(profileName)))
        .go();
  }

  Future<void> deleteAllSubscriptionsForProfile(String profileName) async {
    await (delete(subscriptions)
          ..where((t) => t.profileName.equals(profileName)))
        .go();
  }

  // ============================================================================
  // Search History Operations
  // ============================================================================
  Future<List<SearchHistoryEntry>> getSearchHistory(String profileName) async {
    final query = select(searchHistoryEntries)
      ..where((t) => t.profileName.equals(profileName))
      ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)]);
    return query.get();
  }

  Future<SearchHistoryEntry?> getSearchEntry(
      String queryText, String profileName) async {
    final query = select(searchHistoryEntries)
      ..where(
          (t) => t.query.equals(queryText) & t.profileName.equals(profileName));
    return query.getSingleOrNull();
  }

  Future<void> upsertSearchHistory(SearchHistoryEntriesCompanion entry) async {
    await into(searchHistoryEntries).insert(
      entry,
      onConflict: DoUpdate(
        (old) => entry,
        target: [searchHistoryEntries.query, searchHistoryEntries.profileName],
      ),
    );
  }

  Future<void> deleteSearchEntry(String queryText, String profileName) async {
    await (delete(searchHistoryEntries)
          ..where((t) =>
              t.query.equals(queryText) & t.profileName.equals(profileName)))
        .go();
  }

  Future<void> clearSearchHistory(String profileName) async {
    await (delete(searchHistoryEntries)
          ..where((t) => t.profileName.equals(profileName)))
        .go();
  }

  // ============================================================================
  // User Interaction Operations
  // ============================================================================
  Future<List<UserInteraction>> getInteractions(String profileName,
      {int? limit}) async {
    final query = select(userInteractions)
      ..where((t) => t.profileName.equals(profileName))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<List<UserInteraction>> getInteractionsByType(
      String profileName, int type,
      {int? limit}) async {
    final query = select(userInteractions)
      ..where((t) =>
          t.profileName.equals(profileName) & t.interactionType.equals(type))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<void> upsertInteraction(UserInteractionsCompanion interaction) async {
    await into(userInteractions).insert(
      interaction,
      onConflict: DoUpdate(
        (old) => interaction,
        target: [
          userInteractions.interactionType,
          userInteractions.entityId,
          userInteractions.profileName
        ],
      ),
    );
  }

  Future<void> deleteOldInteractions(
      String profileName, DateTime before) async {
    await (delete(userInteractions)
          ..where((t) =>
              t.profileName.equals(profileName) &
              t.timestamp.isSmallerThanValue(before)))
        .go();
  }

  // ============================================================================
  // User Topic Preference Operations
  // ============================================================================
  Future<List<UserTopicPreference>> getTopicPreferences(String profileName,
      {int? limit}) async {
    final query = select(userTopicPreferences)
      ..where((t) => t.profileName.equals(profileName))
      ..orderBy([(t) => OrderingTerm.desc(t.relevanceScore)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<UserTopicPreference?> getTopicPreference(
      String topic, String profileName) async {
    final query = select(userTopicPreferences)
      ..where((t) => t.topic.equals(topic) & t.profileName.equals(profileName));
    return query.getSingleOrNull();
  }

  Future<void> upsertTopicPreference(
      UserTopicPreferencesCompanion preference) async {
    await into(userTopicPreferences).insert(
      preference,
      onConflict: DoUpdate(
        (old) => preference,
        target: [userTopicPreferences.topic, userTopicPreferences.profileName],
      ),
    );
  }

  // ============================================================================
  // Download Operations
  // ============================================================================
  Future<List<DownloadItem>> getAllDownloads(String profileName) async {
    final query = select(downloadItems)
      ..where((t) => t.profileName.equals(profileName))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<List<DownloadItem>> getDownloadsByStatus(
      String profileName, int status) async {
    final query = select(downloadItems)
      ..where(
          (t) => t.profileName.equals(profileName) & t.status.equals(status))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<DownloadItem?> getDownloadById(int downloadId) async {
    final query = select(downloadItems)..where((t) => t.id.equals(downloadId));
    return query.getSingleOrNull();
  }

  Future<DownloadItem?> getDownloadByVideoId(
      String videoId, String profileName) async {
    final query = select(downloadItems)
      ..where(
          (t) => t.videoId.equals(videoId) & t.profileName.equals(profileName));
    return query.getSingleOrNull();
  }

  Future<int> insertDownload(DownloadItemsCompanion download) async {
    return into(downloadItems).insert(download);
  }

  Future<void> updateDownload(DownloadItemsCompanion download) async {
    await (update(downloadItems)..where((t) => t.id.equals(download.id.value)))
        .write(download);
  }

  Future<void> deleteDownload(int downloadId) async {
    await (delete(downloadItems)..where((t) => t.id.equals(downloadId))).go();
  }

  Future<int> getActiveDownloadsCount() async {
    final query = select(downloadItems)
      ..where((t) => t.status.equals(1)); // downloading status
    final results = await query.get();
    return results.length;
  }

  Future<DownloadItem?> getCompletedDownload(
      String videoId, String profileName) async {
    final query = select(downloadItems)
      ..where((t) =>
          t.videoId.equals(videoId) &
          t.profileName.equals(profileName) &
          t.status.equals(3)); // completed status
    return query.getSingleOrNull();
  }
}

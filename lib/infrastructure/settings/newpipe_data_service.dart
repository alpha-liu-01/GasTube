import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/infrastructure/database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Service for NewPipe-compatible data import/export
/// Creates/reads ZIP files with newpipe.db, newpipe.settings, and preferences.json
@lazySingleton
class NewPipeDataService {
  AppDatabase get db => AppDatabase.instance;

  /// Export data as NewPipe-compatible ZIP file
  /// Contains: newpipe.db (SQLite), newpipe.settings (Java serialized), preferences.json
  Future<Either<MainFailure, String>> exportAsNewPipeZip({
    String profileName = 'default',
    bool includeSettings = true,
  }) async {
    Directory? exportDir;
    try {
      if (UbuntuTouch.enabled) {
        final exports = await ubuntuTouchExportsDirectory();
        exportDir = Directory(p.join(exports.path, '.fluxtube_export'));
      } else {
        final tempDir = await getTemporaryDirectory();
        exportDir = Directory(p.join(tempDir.path, 'fluxtube_export'));
      }
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      await exportDir.create();

      // 1. Create NewPipe SQLite database
      final dbPath = '${exportDir.path}/newpipe.db';
      await _createNewPipeDatabase(dbPath, profileName);

      // 2. Create preferences.json (FluxTube settings in JSON format)
      final prefsPath = '${exportDir.path}/preferences.json';
      await _createPreferencesJson(prefsPath, profileName);

      // 3. Create newpipe.settings (minimal Java serialized format - mostly empty)
      // NewPipe uses Java ObjectOutputStream format, we'll create a minimal version
      final settingsPath = '${exportDir.path}/newpipe.settings';
      await _createNewPipeSettings(settingsPath);

      // Compress off the UI isolate. The database can be large.
      final zipData = await Isolate.run(
        () => _encodeNewPipeZip(dbPath, prefsPath, settingsPath),
      );

      // Save ZIP file
      final Directory? docsDir;
      if (UbuntuTouch.enabled) {
        docsDir = await ubuntuTouchExportsDirectory();
      } else {
        docsDir = await getDownloadsDirectory();
      }
      if (docsDir == null) {
        return const Left(MainFailure.clientFailure());
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .substring(0, 15);
      final profileSuffix = profileName == 'default' ? '' : '_$profileName';
      final zipPath =
          p.join(docsDir.path, 'FluxTubeData$profileSuffix-$timestamp.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);
      if (UbuntuTouch.enabled) {
        print('gastube: export zip file=$zipPath');
      }

      return Right(zipPath);
    } catch (e) {
      print('gastube: export zip failed error=$e');
      return const Left(MainFailure.clientFailure());
    } finally {
      final staging = exportDir;
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  /// Import data from NewPipe ZIP file
  Future<Either<MainFailure, ImportResult>> importFromNewPipeZip({
    required String zipPath,
    String profileName = 'default',
    bool importSubscriptions = true,
    bool importSearchHistory = true,
    bool importWatchHistory = true,
    bool importPlaylists = true,
  }) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        return const Left(MainFailure.clientFailure());
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      int subscriptionsImported = 0;
      int searchHistoryImported = 0;
      int watchHistoryImported = 0;
      int playlistsImported = 0;

      // Find and process files
      ArchiveFile? dbFile;
      ArchiveFile? prefsFile;

      for (final file in archive) {
        if (file.name == 'newpipe.db') {
          dbFile = file;
        } else if (file.name == 'preferences.json') {
          prefsFile = file;
        }
      }

      // Process database if found
      if (dbFile != null) {
        final tempDir = await getTemporaryDirectory();
        final tempDbPath = '${tempDir.path}/import_newpipe.db';
        final tempDbFile = File(tempDbPath);
        await tempDbFile.writeAsBytes(dbFile.content as List<int>);

        final result = await _importFromNewPipeDb(
          tempDbPath,
          profileName,
          importSubscriptions: importSubscriptions,
          importSearchHistory: importSearchHistory,
          importWatchHistory: importWatchHistory,
          importPlaylists: importPlaylists,
        );

        result.fold(
          (failure) => null,
          (counts) {
            subscriptionsImported = counts['subscriptions'] ?? 0;
            searchHistoryImported = counts['searchHistory'] ?? 0;
            watchHistoryImported = counts['watchHistory'] ?? 0;
            playlistsImported = counts['playlists'] ?? 0;
          },
        );

        await tempDbFile.delete();
      }

      // Process preferences.json for FluxTube-specific settings (optional)
      // We only use this for FluxTube-to-FluxTube transfers, not NewPipe
      if (prefsFile != null) {
        // Could parse and import FluxTube-specific settings here
        // For now, we skip this as user requested settings to be FluxTube-only
      }

      return Right(ImportResult(
        subscriptionsImported: subscriptionsImported,
        searchHistoryImported: searchHistoryImported,
        watchHistoryImported: watchHistoryImported,
        playlistsImported: playlistsImported,
      ));
    } catch (e) {
      return const Left(MainFailure.clientFailure());
    }
  }

  /// Create NewPipe-compatible SQLite database.
  ///
  /// Row writes run on another isolate, inside one transaction. Doing them
  /// here froze the UI for minutes: each insert was its own commit.
  Future<void> _createNewPipeDatabase(String dbPath, String profileName) async {
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }

    final subscriptions = await db.getAllSubscriptions(profileName);
    final searchHistory = await db.getSearchHistory(profileName);
    final watchHistory = await db.getHistoryVideos(profileName);
    final savedVideos = await db.getSavedVideos(profileName);
    print(
      'gastube: export zip rows subs=${subscriptions.length} '
      'search=${searchHistory.length} history=${watchHistory.length} '
      'saved=${savedVideos.length}',
    );

    final payload = <String, Object?>{
      'subscriptions': [
        for (final sub in subscriptions)
          <String, Object?>{
            'channelId': sub.channelId,
            'channelName': sub.channelName,
            'avatarUrl': sub.avatarUrl,
          },
      ],
      'searches': [
        for (final search in searchHistory)
          <String, Object?>{
            'at': search.searchedAt.millisecondsSinceEpoch,
            'query': search.query,
          },
      ],
      'history': [
        for (final video in watchHistory) _exportVideo(video),
      ],
      'saved': [
        for (final video in savedVideos) _exportVideo(video),
      ],
    };

    await Isolate.run(() => _writeNewPipeDatabase(dbPath, payload));
  }

  Map<String, Object?> _exportVideo(LocalStoreVideo video) {
    return <String, Object?>{
      'videoId': video.videoId,
      'title': video.title,
      'isLive': video.isLive,
      'duration': video.duration,
      'uploaderName': video.uploaderName,
      'uploaderId': video.uploaderId,
      'thumbnail': video.thumbnail,
      'views': video.views,
      'uploadedDate': video.uploadedDate,
      'timeMs': video.time?.millisecondsSinceEpoch,
      'playbackPosition': video.playbackPosition,
    };
  }


  /// Create preferences.json (FluxTube settings + NewPipe compatible format)
  Future<void> _createPreferencesJson(String path, String profileName) async {
    // Create a combined format that works for both NewPipe and FluxTube
    final prefs = {
      // NewPipe standard fields
      'default_resolution': '720p60',
      'content_country': 'system',
      'content_language': 'system',
      'theme': 'auto_device_theme',
      'enable_watch_history': true,
      'enable_search_history': true,
      'show_comments': true,
      'show_description': true,
      'last_used_preferences_version': 8,
      // FluxTube specific (will be ignored by NewPipe)
      'fluxtube_profile': profileName,
      'fluxtube_version': '0.9.0',
    };

    final file = File(path);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(prefs));
  }

  /// Create minimal newpipe.settings file (Java serialized HashMap)
  /// NewPipe reads this but we provide minimal data since it's complex format
  Future<void> _createNewPipeSettings(String path) async {
    // Java ObjectOutputStream format is complex
    // We create a minimal valid header that NewPipe can parse
    // Most settings will come from preferences.json anyway
    final bytes = <int>[
      // Java serialization magic + version
      0xAC, 0xED, 0x00, 0x05,
      // HashMap type descriptor
      0x73, 0x72, 0x00, 0x11,
      // "java.util.HashMap"
      0x6A, 0x61, 0x76, 0x61, 0x2E, 0x75, 0x74, 0x69, 0x6C, 0x2E, 0x48, 0x61,
      0x73, 0x68, 0x4D, 0x61, 0x70,
      // Hash code and serialVersionUID
      0x05, 0x07, 0xDA, 0xC1, 0xC3, 0x16, 0x60, 0xD1, 0x03, 0x00, 0x02,
      // Fields
      0x46, 0x00, 0x0A, 0x6C, 0x6F, 0x61, 0x64, 0x46, 0x61, 0x63, 0x74, 0x6F,
      0x72,
      0x49, 0x00, 0x09, 0x74, 0x68, 0x72, 0x65, 0x73, 0x68, 0x6F, 0x6C, 0x64,
      // Empty map
      0x78, 0x70, 0x3F, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x77, 0x08,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x78,
    ];

    final file = File(path);
    await file.writeAsBytes(bytes);
  }

  /// Import data from NewPipe SQLite database
  Future<Either<MainFailure, Map<String, int>>> _importFromNewPipeDb(
    String dbPath,
    String profileName, {
    required bool importSubscriptions,
    required bool importSearchHistory,
    required bool importWatchHistory,
    required bool importPlaylists,
  }) async {
    try {
      final newPipeDb = _NewPipeSqlite.openReadOnly(dbPath);
      try {
      int subscriptionsCount = 0;
      int searchHistoryCount = 0;
      int watchHistoryCount = 0;
      int playlistsCount = 0;

      // Import subscriptions
      if (importSubscriptions) {
        try {
          final subs = await newPipeDb.query('subscriptions');
          for (final sub in subs) {
            final url = sub['url'] as String? ?? '';
            final name = sub['name'] as String? ?? '';
            final avatarUrl = sub['avatar_url'] as String?;

            // Extract channel ID from URL
            String? channelId;
            if (url.contains('/channel/')) {
              channelId = url.split('/channel/').last.split('/').first.split('?').first;
            }

            if (channelId != null && channelId.isNotEmpty) {
              // Check if already exists
              final existing = await db.getSubscription(channelId, profileName);

              if (existing == null) {
                await db.upsertSubscription(SubscriptionsCompanion.insert(
                  channelId: channelId,
                  profileName: profileName,
                  channelName: name,
                  avatarUrl: Value(avatarUrl),
                ));
                subscriptionsCount++;
              }
            }
          }
        } catch (_) {
          // Table might not exist
        }
      }

      // Import search history
      if (importSearchHistory) {
        try {
          final searches = await newPipeDb.query('search_history');
          for (final search in searches) {
            final query = search['search'] as String? ?? '';
            final creationDate = search['creation_date'] as int?;

            if (query.isNotEmpty) {
              // Check if already exists
              final existing = await db.getSearchEntry(query, profileName);

              if (existing == null) {
                await db.upsertSearchHistory(SearchHistoryEntriesCompanion.insert(
                  query: query,
                  profileName: profileName,
                  searchedAt: creationDate != null
                      ? DateTime.fromMillisecondsSinceEpoch(creationDate)
                      : DateTime.now(),
                ));
                searchHistoryCount++;
              }
            }
          }
        } catch (_) {
          // Table might not exist
        }
      }

      // Import watch history
      if (importWatchHistory) {
        try {
          // First get streams, then match with stream_history
          final streams = await newPipeDb.query('streams');
          final streamHistory = await newPipeDb.query('stream_history');
          final streamStates = await newPipeDb.query('stream_state');

          // Create lookup maps
          final historyByStreamId = <int, Map<String, dynamic>>{};
          for (final h in streamHistory) {
            historyByStreamId[h['stream_id'] as int] = h;
          }
          final stateByStreamId = <int, Map<String, dynamic>>{};
          for (final s in streamStates) {
            stateByStreamId[s['stream_id'] as int] = s;
          }

          for (final stream in streams) {
            final uid = stream['uid'] as int;
            final url = stream['url'] as String? ?? '';
            final history = historyByStreamId[uid];
            final state = stateByStreamId[uid];

            // Only import if it has history (was watched)
            if (history == null) continue;

            // Extract video ID from URL
            String? videoId;
            if (url.contains('watch?v=')) {
              videoId = url.split('watch?v=').last.split('&').first;
            }

            if (videoId != null && videoId.isNotEmpty) {
              // Check if already exists
              final existing = await db.getVideoById(videoId, profileName);

              if (existing == null) {
                final accessDate = history['access_date'] as int?;
                final progressTime = state?['progress_time'] as int?;

                await db.upsertVideo(LocalStoreVideosCompanion.insert(
                  videoId: videoId,
                  profileName: profileName,
                  title: Value(stream['title'] as String?),
                  views: Value(stream['view_count'] as int?),
                  thumbnail: Value(stream['thumbnail_url'] as String?),
                  uploadedDate: Value(stream['textual_upload_date'] as String?),
                  uploaderName: Value(stream['uploader'] as String?),
                  uploaderId: Value(_extractChannelId(stream['uploader_url'] as String?)),
                  duration: Value(stream['duration'] as int?),
                  isHistory: const Value(true),
                  isSaved: const Value(false),
                  isLive: Value(stream['stream_type'] == 'LIVE_STREAM'),
                  playbackPosition: Value(progressTime != null ? progressTime ~/ 1000 : null),
                  time: Value(accessDate != null
                      ? DateTime.fromMillisecondsSinceEpoch(accessDate)
                      : DateTime.now()),
                ));
                watchHistoryCount++;
              }
            }
          }
        } catch (_) {
          // Tables might not exist
        }
      }

      // Import playlists (as saved videos for now)
      if (importPlaylists) {
        try {
          final playlistJoins = await newPipeDb.query('playlist_stream_join');
          final streams = await newPipeDb.query('streams');

          // Create stream lookup
          final streamById = <int, Map<String, dynamic>>{};
          for (final s in streams) {
            streamById[s['uid'] as int] = s;
          }

          for (final join in playlistJoins) {
            final streamId = join['stream_id'] as int;
            final stream = streamById[streamId];
            if (stream == null) continue;

            final url = stream['url'] as String? ?? '';
            String? videoId;
            if (url.contains('watch?v=')) {
              videoId = url.split('watch?v=').last.split('&').first;
            }

            if (videoId != null && videoId.isNotEmpty) {
              // Check if already exists
              final existing = await db.getVideoById(videoId, profileName);

              if (existing == null) {
                // Create new saved entry
                await db.upsertVideo(LocalStoreVideosCompanion.insert(
                  videoId: videoId,
                  profileName: profileName,
                  title: Value(stream['title'] as String?),
                  views: Value(stream['view_count'] as int?),
                  thumbnail: Value(stream['thumbnail_url'] as String?),
                  uploadedDate: Value(stream['textual_upload_date'] as String?),
                  uploaderName: Value(stream['uploader'] as String?),
                  uploaderId: Value(_extractChannelId(stream['uploader_url'] as String?)),
                  duration: Value(stream['duration'] as int?),
                  isHistory: const Value(false),
                  isSaved: const Value(true),
                  isLive: Value(stream['stream_type'] == 'LIVE_STREAM'),
                ));
                playlistsCount++;
              } else if (!existing.isSaved) {
                // Update existing to also be saved
                await db.upsertVideo(LocalStoreVideosCompanion(
                  videoId: Value(videoId),
                  profileName: Value(profileName),
                  isSaved: const Value(true),
                ));
                playlistsCount++;
              }
            }
          }
        } catch (_) {
          // Tables might not exist
        }
      }

      return Right({
        'subscriptions': subscriptionsCount,
        'searchHistory': searchHistoryCount,
        'watchHistory': watchHistoryCount,
        'playlists': playlistsCount,
      });
      } finally {
        await newPipeDb.close();
      }
    } catch (e) {
      print('gastube: import zip db failed error=$e');
      return const Left(MainFailure.clientFailure());
    }
  }

  String? _extractChannelId(String? uploaderUrl) {
    if (uploaderUrl == null) return null;
    if (uploaderUrl.contains('/channel/')) {
      return uploaderUrl.split('/channel/').last.split('/').first.split('?').first;
    }
    return null;
  }
}

/// Writes a NewPipe SQLite file without sqflite. Linux builds, including
/// the Ubuntu Touch click, do not register an sqflite implementation.
List<int> _encodeNewPipeZip(
  String dbPath,
  String prefsPath,
  String settingsPath,
) {
  final archive = Archive();
  void add(String name, String path) {
    final bytes = File(path).readAsBytesSync();
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('newpipe.db', dbPath);
  add('preferences.json', prefsPath);
  add('newpipe.settings', settingsPath);
  return ZipEncoder().encode(archive);
}

void _writeNewPipeDatabase(String dbPath, Map<String, Object?> payload) {
  final db = sqlite.sqlite3.open(dbPath);
  try {
    db.execute('CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT)');
    db.execute('''
        CREATE TABLE subscriptions (
          uid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          service_id INTEGER NOT NULL,
          url TEXT,
          name TEXT,
          avatar_url TEXT,
          subscriber_count INTEGER,
          description TEXT,
          notification_mode INTEGER NOT NULL DEFAULT 0
        )
      ''');
    db.execute('''
        CREATE UNIQUE INDEX index_subscriptions_service_id_url
        ON subscriptions (service_id, url)
      ''');
    db.execute('''
        CREATE TABLE search_history (
          creation_date INTEGER,
          service_id INTEGER NOT NULL,
          search TEXT,
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
        )
      ''');
    db.execute('''
        CREATE INDEX index_search_history_search ON search_history (search)
      ''');
    db.execute('''
        CREATE TABLE streams (
          uid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          service_id INTEGER NOT NULL,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          stream_type TEXT NOT NULL,
          duration INTEGER NOT NULL,
          uploader TEXT NOT NULL,
          uploader_url TEXT,
          thumbnail_url TEXT,
          view_count INTEGER,
          textual_upload_date TEXT,
          upload_date INTEGER,
          is_upload_date_approximation INTEGER
        )
      ''');
    db.execute('''
        CREATE UNIQUE INDEX index_streams_service_id_url ON streams (service_id, url)
      ''');
    db.execute('''
        CREATE TABLE stream_history (
          stream_id INTEGER NOT NULL,
          access_date INTEGER NOT NULL,
          repeat_count INTEGER NOT NULL,
          PRIMARY KEY(stream_id, access_date),
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
    db.execute('''
        CREATE INDEX index_stream_history_stream_id ON stream_history (stream_id)
      ''');
    db.execute('''
        CREATE TABLE stream_state (
          stream_id INTEGER NOT NULL,
          progress_time INTEGER NOT NULL,
          PRIMARY KEY(stream_id),
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
    db.execute('''
        CREATE TABLE playlists (
          uid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT,
          is_thumbnail_permanent INTEGER NOT NULL DEFAULT 0,
          thumbnail_stream_id INTEGER NOT NULL DEFAULT -1,
          display_index INTEGER NOT NULL DEFAULT 0
        )
      ''');
    db.execute('''
        CREATE TABLE playlist_stream_join (
          playlist_id INTEGER NOT NULL,
          stream_id INTEGER NOT NULL,
          join_index INTEGER NOT NULL,
          PRIMARY KEY(playlist_id, join_index),
          FOREIGN KEY(playlist_id) REFERENCES playlists(uid) ON UPDATE CASCADE ON DELETE CASCADE,
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
    db.execute('''
        CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)
      ''');
    db.execute(
      "INSERT INTO room_master_table (id, identity_hash) VALUES (42, 'fluxtube_export')",
    );

    final insertSub = db.prepare(
      'INSERT INTO subscriptions (service_id, url, name, avatar_url, subscriber_count, description, notification_mode) VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    final insertSearch = db.prepare(
      'INSERT INTO search_history (creation_date, service_id, search) VALUES (?, ?, ?)',
    );
    final insertStream = db.prepare(
      'INSERT INTO streams (service_id, url, title, stream_type, duration, uploader, uploader_url, thumbnail_url, view_count, textual_upload_date, upload_date, is_upload_date_approximation) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    final insertHistory = db.prepare(
      'INSERT INTO stream_history (stream_id, access_date, repeat_count) VALUES (?, ?, ?)',
    );
    final insertState = db.prepare(
      'INSERT INTO stream_state (stream_id, progress_time) VALUES (?, ?)',
    );
    final insertJoin = db.prepare(
      'INSERT INTO playlist_stream_join (playlist_id, stream_id, join_index) VALUES (?, ?, ?)',
    );
    db.execute('BEGIN');
    try {
      for (final raw in payload['subscriptions']! as List) {
        final sub = raw as Map;
        insertSub.execute([
          0,
          'https://www.youtube.com/channel/${sub['channelId']}',
          sub['channelName'],
          sub['avatarUrl'],
          null,
          null,
          0,
        ]);
      }
      for (final raw in payload['searches']! as List) {
        final search = raw as Map;
        insertSearch.execute([search['at'], 0, search['query']]);
      }

      final urlToId = <String, int>{};
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final raw in payload['history']! as List) {
        final video = raw as Map;
        final url = 'https://www.youtube.com/watch?v=${video['videoId']}';
        insertStream.execute(_newPipeStreamRow(video, url, video['timeMs']));
        final streamId = db.lastInsertRowId;
        urlToId[url] = streamId;
        insertHistory.execute([streamId, video['timeMs'] ?? nowMs, 1]);
        final position = video['playbackPosition'] as int?;
        if (position != null && position > 0) {
          insertState.execute([streamId, position * 1000]);
        }
      }

      final saved = payload['saved']! as List;
      if (saved.isNotEmpty) {
        db.execute(
          "INSERT INTO playlists (name, is_thumbnail_permanent, thumbnail_stream_id, display_index) VALUES ('FluxTube Saved', 0, -1, 0)",
        );
        final playlistId = db.lastInsertRowId;
        var joinIndex = 0;
        for (final raw in saved) {
          final video = raw as Map;
          final url = 'https://www.youtube.com/watch?v=${video['videoId']}';
          var streamId = urlToId[url];
          if (streamId == null) {
            insertStream.execute(_newPipeStreamRow(video, url, null));
            streamId = db.lastInsertRowId;
            urlToId[url] = streamId;
          }
          insertJoin.execute([playlistId, streamId, joinIndex]);
          joinIndex += 1;
        }
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      insertSub.dispose();
      insertSearch.dispose();
      insertStream.dispose();
      insertHistory.dispose();
      insertState.dispose();
      insertJoin.dispose();
    }
  } finally {
    db.dispose();
  }
}

List<Object?> _newPipeStreamRow(Map video, String url, Object? uploadDate) {
  final uploaderId = video['uploaderId'] as String?;
  return [
    0,
    url,
    video['title'] ?? '',
    video['isLive'] == true ? 'LIVE_STREAM' : 'VIDEO_STREAM',
    video['duration'] ?? 0,
    video['uploaderName'] ?? '',
    uploaderId == null ? null : 'https://www.youtube.com/channel/$uploaderId',
    video['thumbnail'],
    video['views'],
    video['uploadedDate'],
    uploadDate,
    1,
  ];
}

class _NewPipeSqlite {
  _NewPipeSqlite(this._db);

  final sqlite.Database _db;

  static _NewPipeSqlite openReadOnly(String path) {
    return _NewPipeSqlite(
      sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly),
    );
  }

  Future<void> execute(String sql) async {
    _db.execute(sql);
  }

  Future<int> insert(String table, Map<String, Object?> values) async {
    final columns = values.keys.toList(growable: false);
    _db.execute(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      [for (final column in columns) values[column]],
    );
    return _db.lastInsertRowId;
  }

  Future<List<sqlite.Row>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (where == null) {
      return _db.select('SELECT * FROM $table');
    }
    return _db.select(
      'SELECT * FROM $table WHERE $where',
      whereArgs ?? const <Object?>[],
    );
  }

  Future<void> close() async {
    _db.dispose();
  }
}

/// Result of import operation
class ImportResult {
  final int subscriptionsImported;
  final int searchHistoryImported;
  final int watchHistoryImported;
  final int playlistsImported;

  ImportResult({
    required this.subscriptionsImported,
    required this.searchHistoryImported,
    required this.watchHistoryImported,
    required this.playlistsImported,
  });

  int get totalImported =>
      subscriptionsImported +
      searchHistoryImported +
      watchHistoryImported +
      playlistsImported;

  @override
  String toString() {
    return 'Imported: $subscriptionsImported subscriptions, '
        '$searchHistoryImported searches, $watchHistoryImported history, '
        '$playlistsImported playlist items';
  }
}

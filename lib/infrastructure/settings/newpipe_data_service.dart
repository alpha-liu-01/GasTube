import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/ubuntu_touch_content_hub.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/infrastructure/database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
    try {
      final tempDir = await getTemporaryDirectory();
      final exportDir = Directory('${tempDir.path}/fluxtube_export');
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

      // 4. Create ZIP archive
      final archive = Archive();

      // Add newpipe.db
      final dbFile = File(dbPath);
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('newpipe.db', dbBytes.length, dbBytes));

      // Add preferences.json
      final prefsFile = File(prefsPath);
      final prefsBytes = await prefsFile.readAsBytes();
      archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));

      // Add newpipe.settings
      final settingsFile = File(settingsPath);
      final settingsBytes = await settingsFile.readAsBytes();
      archive.addFile(
          ArchiveFile('newpipe.settings', settingsBytes.length, settingsBytes));

      // Encode to ZIP
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

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
        final handed = await exportDocument(zipPath);
        if (!handed.ok) {
          return const Left(MainFailure.clientFailure());
        }
      }

      // Cleanup temp directory
      await exportDir.delete(recursive: true);

      return Right(zipPath);
    } catch (e) {
      return const Left(MainFailure.clientFailure());
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

  /// Create NewPipe-compatible SQLite database
  Future<void> _createNewPipeDatabase(String dbPath, String profileName) async {
    // Delete existing file if any
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Open SQLite database
    final newPipeDb = await openDatabase(dbPath, version: 1, onCreate: (newPipeDb, version) async {
      // Create NewPipe schema
      await newPipeDb.execute('''
        CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT)
      ''');
      await newPipeDb.execute('''
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
      await newPipeDb.execute('''
        CREATE UNIQUE INDEX index_subscriptions_service_id_url
        ON subscriptions (service_id, url)
      ''');
      await newPipeDb.execute('''
        CREATE TABLE search_history (
          creation_date INTEGER,
          service_id INTEGER NOT NULL,
          search TEXT,
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
        )
      ''');
      await newPipeDb.execute('''
        CREATE INDEX index_search_history_search ON search_history (search)
      ''');
      await newPipeDb.execute('''
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
      await newPipeDb.execute('''
        CREATE UNIQUE INDEX index_streams_service_id_url ON streams (service_id, url)
      ''');
      await newPipeDb.execute('''
        CREATE TABLE stream_history (
          stream_id INTEGER NOT NULL,
          access_date INTEGER NOT NULL,
          repeat_count INTEGER NOT NULL,
          PRIMARY KEY(stream_id, access_date),
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
      await newPipeDb.execute('''
        CREATE INDEX index_stream_history_stream_id ON stream_history (stream_id)
      ''');
      await newPipeDb.execute('''
        CREATE TABLE stream_state (
          stream_id INTEGER NOT NULL,
          progress_time INTEGER NOT NULL,
          PRIMARY KEY(stream_id),
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
      await newPipeDb.execute('''
        CREATE TABLE playlists (
          uid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT,
          is_thumbnail_permanent INTEGER NOT NULL DEFAULT 0,
          thumbnail_stream_id INTEGER NOT NULL DEFAULT -1,
          display_index INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await newPipeDb.execute('''
        CREATE TABLE playlist_stream_join (
          playlist_id INTEGER NOT NULL,
          stream_id INTEGER NOT NULL,
          join_index INTEGER NOT NULL,
          PRIMARY KEY(playlist_id, join_index),
          FOREIGN KEY(playlist_id) REFERENCES playlists(uid) ON UPDATE CASCADE ON DELETE CASCADE,
          FOREIGN KEY(stream_id) REFERENCES streams(uid) ON UPDATE CASCADE ON DELETE CASCADE
        )
      ''');
      await newPipeDb.execute('''
        CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)
      ''');
      await newPipeDb.insert('room_master_table', {
        'id': 42,
        'identity_hash': 'fluxtube_export',
      });
    });

    // Export subscriptions from Drift DB
    final subscriptions = await db.getAllSubscriptions(profileName);

    for (final sub in subscriptions) {
      await newPipeDb.insert('subscriptions', {
        'service_id': 0, // 0 = YouTube
        'url': 'https://www.youtube.com/channel/${sub.channelId}',
        'name': sub.channelName,
        'avatar_url': sub.avatarUrl,
        'subscriber_count': null,
        'description': null,
        'notification_mode': 0,
      });
    }

    // Export search history from Drift DB
    final searchHistory = await db.getSearchHistory(profileName);

    for (final search in searchHistory) {
      await newPipeDb.insert('search_history', {
        'creation_date': search.searchedAt.millisecondsSinceEpoch,
        'service_id': 0,
        'search': search.query,
      });
    }

    // Export watch history (as streams + stream_history) from Drift DB
    final watchHistory = await db.getHistoryVideos(profileName);

    for (final video in watchHistory) {
      // Insert into streams table
      final streamId = await newPipeDb.insert('streams', {
        'service_id': 0,
        'url': 'https://www.youtube.com/watch?v=${video.videoId}',
        'title': video.title ?? '',
        'stream_type': video.isLive == true ? 'LIVE_STREAM' : 'VIDEO_STREAM',
        'duration': video.duration ?? 0,
        'uploader': video.uploaderName ?? '',
        'uploader_url': video.uploaderId != null
            ? 'https://www.youtube.com/channel/${video.uploaderId}'
            : null,
        'thumbnail_url': video.thumbnail,
        'view_count': video.views,
        'textual_upload_date': video.uploadedDate,
        'upload_date': video.time?.millisecondsSinceEpoch,
        'is_upload_date_approximation': 1,
      });

      // Insert into stream_history
      await newPipeDb.insert('stream_history', {
        'stream_id': streamId,
        'access_date': video.time?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        'repeat_count': 1,
      });

      // Insert playback position into stream_state if available
      if (video.playbackPosition != null && video.playbackPosition! > 0) {
        await newPipeDb.insert('stream_state', {
          'stream_id': streamId,
          'progress_time': video.playbackPosition! * 1000, // Convert to ms
        });
      }
    }

    // Export saved videos as a playlist named "FluxTube Saved"
    final savedVideos = await db.getSavedVideos(profileName);

    if (savedVideos.isNotEmpty) {
      final playlistId = await newPipeDb.insert('playlists', {
        'name': 'FluxTube Saved',
        'is_thumbnail_permanent': 0,
        'thumbnail_stream_id': -1,
        'display_index': 0,
      });

      int joinIndex = 0;
      for (final video in savedVideos) {
        // First, ensure stream exists
        final existingStream = await newPipeDb.query(
          'streams',
          where: 'url = ?',
          whereArgs: ['https://www.youtube.com/watch?v=${video.videoId}'],
        );

        int streamId;
        if (existingStream.isEmpty) {
          streamId = await newPipeDb.insert('streams', {
            'service_id': 0,
            'url': 'https://www.youtube.com/watch?v=${video.videoId}',
            'title': video.title ?? '',
            'stream_type': video.isLive == true ? 'LIVE_STREAM' : 'VIDEO_STREAM',
            'duration': video.duration ?? 0,
            'uploader': video.uploaderName ?? '',
            'uploader_url': video.uploaderId != null
                ? 'https://www.youtube.com/channel/${video.uploaderId}'
                : null,
            'thumbnail_url': video.thumbnail,
            'view_count': video.views,
            'textual_upload_date': video.uploadedDate,
            'upload_date': null,
            'is_upload_date_approximation': 1,
          });
        } else {
          streamId = existingStream.first['uid'] as int;
        }

        await newPipeDb.insert('playlist_stream_join', {
          'playlist_id': playlistId,
          'stream_id': streamId,
          'join_index': joinIndex++,
        });
      }
    }

    await newPipeDb.close();
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
      final newPipeDb = await openDatabase(dbPath, readOnly: true);
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

      await newPipeDb.close();

      return Right({
        'subscriptions': subscriptionsCount,
        'searchHistory': searchHistoryCount,
        'watchHistory': watchHistoryCount,
        'playlists': playlistsCount,
      });
    } catch (e) {
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

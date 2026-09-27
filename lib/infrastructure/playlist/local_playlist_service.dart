import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/domain/playlist/models/local_playlist.dart';
import 'package:path/path.dart' as p;

class LocalPlaylistService extends ChangeNotifier {
  static final LocalPlaylistService _instance = LocalPlaylistService._();
  factory LocalPlaylistService() => _instance;
  LocalPlaylistService._();

  final List<LocalPlaylist> _playlists = [];
  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists);
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await persistentAppDirectory();
      final file = File(p.join(dir.path, 'local_playlists.json'));
      if (!await file.exists()) {
        await copyLegacyDocumentFile('local_playlists.json', file);
      }
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        _playlists.clear();
        for (final map in data) {
          _playlists.add(LocalPlaylist.fromMap(map as Map<String, dynamic>));
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final dir = await persistentAppDirectory();
    final file = File(p.join(dir.path, 'local_playlists.json'));
    await file.writeAsString(
        jsonEncode(_playlists.map((p) => p.toMap()).toList()));
  }

  LocalPlaylist create(String name, {String description = ''}) {
    final playlist = LocalPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
    );
    _playlists.add(playlist);
    unawaited(_save());
    notifyListeners();
    return playlist;
  }

  void delete(String id) {
    _playlists.removeWhere((p) => p.id == id);
    unawaited(_save());
    notifyListeners();
  }

  void rename(String id, String newName) {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _playlists[index] = _playlists[index].copyWith(name: newName);
      unawaited(_save());
      notifyListeners();
    }
  }

  bool addVideo(String playlistId, String videoId, String videoTitle,
      {String? thumbnailUrl, String? channelName, String? channelId}) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;
    final playlist = _playlists[index];
    final ids = List<String>.from(playlist.videoIds);
    final titles = List<String>.from(playlist.videoTitles);
    final thumbs = List<String>.from(playlist.thumbnailUrls);
    final chNames = List<String>.from(playlist.channelNames);
    final chIds = List<String>.from(playlist.channelIds);
    if (!ids.contains(videoId)) {
      ids.add(videoId);
      titles.add(videoTitle);
      thumbs.add(thumbnailUrl ?? '');
      chNames.add(channelName ?? '');
      chIds.add(channelId ?? '');
      _playlists[index] = playlist.copyWith(
        videoIds: ids,
        videoTitles: titles,
        thumbnailUrls: thumbs,
        channelNames: chNames,
        channelIds: chIds,
      );
      unawaited(_save());
      notifyListeners();
    }
    return true;
  }

  void removeVideo(String playlistId, String videoId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return;
    final playlist = _playlists[index];
    final vidIndex = playlist.videoIds.indexOf(videoId);
    if (vidIndex < 0) return;

    // Every list is a parallel array indexed by video position, so a removal
    // has to drop the same slot from all of them or the metadata shifts onto
    // the wrong videos.
    List<String> without(List<String> source) {
      if (vidIndex >= source.length) return List<String>.from(source);
      return List<String>.from(source)..removeAt(vidIndex);
    }

    _playlists[index] = playlist.copyWith(
      videoIds: without(playlist.videoIds),
      videoTitles: without(playlist.videoTitles),
      thumbnailUrls: without(playlist.thumbnailUrls),
      channelNames: without(playlist.channelNames),
      channelIds: without(playlist.channelIds),
    );
    unawaited(_save());
    notifyListeners();
  }

  bool hasVideo(String playlistId, String videoId) {
    return getById(playlistId)?.videoIds.contains(videoId) ?? false;
  }

  LocalPlaylist? getById(String id) {
    final index = _playlists.indexWhere((p) => p.id == id);
    return index < 0 ? null : _playlists[index];
  }
}

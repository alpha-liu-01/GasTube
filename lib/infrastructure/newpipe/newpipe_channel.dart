import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fluxtube/domain/channel/models/newpipe/newpipe_channel_resp.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_sidecar.dart';
import 'package:fluxtube/domain/search/models/newpipe/newpipe_search_resp.dart';
import 'package:fluxtube/domain/trending/models/newpipe/newpipe_trending_resp.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_comments_resp.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';

/// NewPipe Extractor bridge. Android uses the Kotlin method channel.
/// Other platforms use the desktop sidecar process.
class NewPipeChannel {
  static const _channel = MethodChannel('com.fazilvk.fluxtube/newpipe');

  // Cache for stream URLs with TTL (5 minutes)
  static final Map<String, _CachedStreamInfo> _streamCache = {};
  static const _cacheTtl = Duration(minutes: 5);

  /// Check if NewPipe Extractor is available on this platform.
  static Future<bool> get isAvailable async {
    if (!Platform.isAndroid) {
      try {
        await NewPipeSidecar.instance.ensureStarted();
        return NewPipeSidecar.instance.isRunning;
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<String> _invoke(String method, Map<String, dynamic> args) async {
    try {
      final String? result = Platform.isAndroid
          ? await _channel.invokeMethod<String>(method, args)
          : await NewPipeSidecar.instance.invoke(method, args);
      if (result == null) {
        throw PlatformException(
          code: 'NULL_RESULT',
          message: 'No data returned from NewPipe Extractor',
        );
      }
      return result;
    } on NewPipeSidecarException catch (error) {
      throw PlatformException(code: error.code, message: error.message);
    }
  }

  /// Get video stream info including metadata and stream URLs
  static Future<NewPipeWatchResp> getStreamInfo(String videoId) async {
    try {
      final result = await _invoke('getStreamInfo', {'id': videoId});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final resp = NewPipeWatchResp.fromJson(json);
      // Cache the result
      _streamCache[videoId] = _CachedStreamInfo(resp, DateTime.now());
      return resp;
    } on PlatformException catch (e) {
      throw Exception('Failed to get stream info: ${e.message}');
    }
  }

  /// Get video stream info fast (essential data only - no related videos).
  /// Use this for faster initial playback. Fetches related videos separately.
  /// Falls back to regular getStreamInfo if fast method is not available.
  static Future<NewPipeWatchResp> getStreamInfoFast(String videoId) async {
    // Check cache first
    final cached = _streamCache[videoId];
    if (cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.data;
    }

    try {
      final result = await _invoke('getStreamInfoFast', {'id': videoId});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final resp = NewPipeWatchResp.fromJson(json);
      // Cache the result
      _streamCache[videoId] = _CachedStreamInfo(resp, DateTime.now());
      return resp;
    } on MissingPluginException {
      // Fall back to regular getStreamInfo if fast method is not available
      // This can happen if native code hasn't been rebuilt
      return getStreamInfo(videoId);
    } on PlatformException catch (e) {
      throw Exception('Failed to get stream info: ${e.message}');
    }
  }

  /// Get cached stream info if available and not expired
  static NewPipeWatchResp? getCachedStreamInfo(String videoId) {
    final cached = _streamCache[videoId];
    if (cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.data;
    }
    return null;
  }

  /// Pre-fetch stream info for a video (e.g., from thumbnails)
  static Future<void> prefetchStreamInfo(String videoId) async {
    // Check if already cached
    final cached = _streamCache[videoId];
    if (cached != null && !cached.isExpired(_cacheTtl)) {
      return;
    }

    try {
      await getStreamInfoFast(videoId);
    } catch (_) {
      // Silently fail for prefetch - it's just an optimization
    }
  }

  /// Clear expired cache entries
  static void clearExpiredCache() {
    _streamCache.removeWhere((_, cached) => cached.isExpired(_cacheTtl));
  }

  /// Clear all cache
  static void clearCache() {
    _streamCache.clear();
  }

  /// Get trending videos for a specific region
  static Future<List<NewPipeTrendingResp>> getTrending(String region) async {
    try {
      final result = await _invoke('getTrending', {'region': region});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final videos = json['videos'] as List<dynamic>?;
      if (videos == null) return [];
      return videos
          .map((v) => NewPipeTrendingResp.fromJson(v as Map<String, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get trending: ${e.message}');
    }
  }

  /// Search for videos, channels, or playlists
  static Future<NewPipeSearchResp> search({
    required String query,
    required String filter,
    String? nextPage,
  }) async {
    try {
      final result = await _invoke('search', {
        'query': query,
        'filter': filter,
        if (nextPage != null) 'nextPage': nextPage,
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeSearchResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to search: ${e.message}');
    }
  }

  /// Get search suggestions for autocomplete
  static Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final result = await _invoke('getSearchSuggestions', {'query': query});
      final json = jsonDecode(result) as List<dynamic>;
      return json.map((s) => s.toString()).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get suggestions: ${e.message}');
    }
  }

  /// Get channel info and videos
  static Future<NewPipeChannelResp> getChannel(String channelId) async {
    try {
      final result = await _invoke('getChannel', {'id': channelId});
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeChannelResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get channel: ${e.message}');
    }
  }

  /// Get comments for a video
  static Future<NewPipeCommentsResp> getComments(String videoId) async {
    try {
      final result = await _invoke('getComments', {'id': videoId});
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeCommentsResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get comments: ${e.message}');
    }
  }

  /// Get more comments (pagination)
  static Future<NewPipeCommentsResp> getMoreComments({
    required String videoId,
    required String nextPage,
  }) async {
    try {
      final result = await _invoke('getMoreComments', {
        'id': videoId,
        'nextPage': nextPage,
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeCommentsResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get more comments: ${e.message}');
    }
  }

  /// Get comment replies
  static Future<NewPipeCommentsResp> getCommentReplies({
    required String videoId,
    required String repliesPage,
  }) async {
    try {
      final result = await _invoke('getCommentReplies', {
        'id': videoId,
        'repliesPage': repliesPage,
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeCommentsResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get comment replies: ${e.message}');
    }
  }

  /// Get channel tab content (shorts, playlists, etc.) by tab URL
  static Future<NewPipeChannelResp> getChannelTab(
    String tabUrl, {
    String? tabId,
    List<String>? contentFilters,
  }) async {
    try {
      final result = await _invoke('getChannelTab', {
        'url': tabUrl,
        if (tabId != null) 'id': tabId,
        if (contentFilters != null) 'contentFilters': contentFilters,
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeChannelResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get channel tab: ${e.message}');
    }
  }

  /// Get more channel tab content (pagination)
  static Future<NewPipeChannelResp> getChannelTabWithPagination(
    String tabUrl, {
    required String nextPage,
    String? tabId,
    List<String>? contentFilters,
  }) async {
    try {
      final result = await _invoke('getChannelTab', {
        'url': tabUrl,
        if (tabId != null) 'id': tabId,
        if (contentFilters != null) 'contentFilters': contentFilters,
        'nextPage': nextPage,
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      return NewPipeChannelResp.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get more channel tab content: ${e.message}');
    }
  }
}

/// Cache entry for stream info with timestamp
class _CachedStreamInfo {
  final NewPipeWatchResp data;
  final DateTime timestamp;

  _CachedStreamInfo(this.data, this.timestamp);

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

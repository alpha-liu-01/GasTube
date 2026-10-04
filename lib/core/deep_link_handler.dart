import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;
  BuildContext? _context;
  final List<String> _pendingSharedText = [];

  void init(BuildContext context) {
    _context = context;
    _appLinks = AppLinks();
    _setupDeepLinkListener();
    _handleInitialLink();
    final pending = List<String>.from(_pendingSharedText);
    _pendingSharedText.clear();
    for (final text in pending) {
      _handleSharedText(text);
    }
    // receive_sharing_intent only has Android and iOS implementations.
    if (Platform.isAndroid || Platform.isIOS) {
      _setupShareIntentListener();
      _handleInitialShareIntent();
    }
  }

  void _setupDeepLinkListener() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    });
  }

  void _setupShareIntentListener() {
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final text = value.first.path;
          _handleSharedText(text);
        }
      },
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  Future<void> _handleInitialShareIntent() async {
    try {
      final List<SharedMediaFile> sharedFiles =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (sharedFiles.isNotEmpty) {
        final text = sharedFiles.first.path;
        _handleSharedText(text);
        ReceiveSharingIntent.instance.reset();
      }
    } catch (e) {
      debugPrint('Error getting initial share intent: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    final result = parseYouTubeUrl(uri.toString());
    if (result != null) {
      _navigateToContent(result);
    }
  }

  void acceptSharedText(String text) {
    if (_context == null || !_context!.mounted) {
      _pendingSharedText.add(text);
      print('gastube: content share queued text=$text');
      return;
    }
    _handleSharedText(text);
  }

  void _handleSharedText(String text) {
    print('gastube: content share text=$text');
    final result = parseYouTubeUrl(text);
    if (result != null) {
      _navigateToContent(result);
    }
  }

  void _navigateToContent(YouTubeLinkResult result) {
    if (_context == null || !_context!.mounted) return;

    switch (result.type) {
      case YouTubeLinkType.video:
        _context!.goNamed(
          'watch',
          pathParameters: {
            'videoId': result.id,
            'channelId': 'unknown',
          },
        );
        break;
      case YouTubeLinkType.channel:
        _context!.goNamed(
          'channel',
          pathParameters: {
            'channelId': result.id,
          },
        );
        break;
      case YouTubeLinkType.playlist:
        _context!.goNamed(
          'playlist',
          pathParameters: {
            'playlistId': result.id,
          },
        );
        break;
    }
  }

  static YouTubeLinkResult? parseYouTubeUrl(String url) {
    // Handle youtu.be short links
    final youtubeShortRegex = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
    final shortMatch = youtubeShortRegex.firstMatch(url);
    if (shortMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.video,
        id: shortMatch.group(1)!,
      );
    }

    // Handle youtube.com/watch?v= links
    final watchRegex = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})');
    final watchMatch = watchRegex.firstMatch(url);
    if (watchMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.video,
        id: watchMatch.group(1)!,
      );
    }

    // Handle youtube.com/v/ links
    final vRegex = RegExp(r'youtube\.com/v/([a-zA-Z0-9_-]{11})');
    final vMatch = vRegex.firstMatch(url);
    if (vMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.video,
        id: vMatch.group(1)!,
      );
    }

    // Handle youtube.com/embed/ links
    final embedRegex = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})');
    final embedMatch = embedRegex.firstMatch(url);
    if (embedMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.video,
        id: embedMatch.group(1)!,
      );
    }

    // Handle youtube.com/shorts/ links
    final shortsRegex = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})');
    final shortsMatch = shortsRegex.firstMatch(url);
    if (shortsMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.video,
        id: shortsMatch.group(1)!,
      );
    }

    // Handle youtube.com/channel/ links
    final channelRegex = RegExp(r'youtube\.com/channel/([a-zA-Z0-9_-]+)');
    final channelMatch = channelRegex.firstMatch(url);
    if (channelMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.channel,
        id: channelMatch.group(1)!,
      );
    }

    // Handle youtube.com/@username links
    final handleRegex = RegExp(r'youtube\.com/@([a-zA-Z0-9_-]+)');
    final handleMatch = handleRegex.firstMatch(url);
    if (handleMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.channel,
        id: '@${handleMatch.group(1)!}',
      );
    }

    // Handle youtube.com/playlist?list= links
    final playlistRegex = RegExp(r'youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)');
    final playlistMatch = playlistRegex.firstMatch(url);
    if (playlistMatch != null) {
      return YouTubeLinkResult(
        type: YouTubeLinkType.playlist,
        id: playlistMatch.group(1)!,
      );
    }

    return null;
  }

  void dispose() {
    _linkSubscription?.cancel();
    _shareSubscription?.cancel();
  }
}

enum YouTubeLinkType {
  video,
  channel,
  playlist,
}

class YouTubeLinkResult {
  final YouTubeLinkType type;
  final String id;

  YouTubeLinkResult({
    required this.type,
    required this.id,
  });
}

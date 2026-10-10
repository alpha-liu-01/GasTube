import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/core/services/media_hub_player.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/ubuntu_touch_content_hub.dart';
import 'package:fluxtube/core/ubuntu_touch_dash_mpd.dart';
import 'package:fluxtube/domain/saved/models/local_store.dart';
import 'package:fluxtube/domain/sponsorblock/models/sponsor_segment.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_stream.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_channel.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';
import 'package:fluxtube/domain/watch/playback/models/playback_configuration.dart';
import 'package:fluxtube/domain/watch/playback/models/stream_quality_info.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/domain/watch/playback/newpipe_playback_resolver.dart';
import 'package:fluxtube/domain/watch/playback/newpipe_stream_helper.dart';
import 'package:fluxtube/domain/watch/playback/video_codec.dart';
import 'package:fluxtube/presentation/watch/queue_playback.dart';
import 'package:fluxtube/presentation/watch/widgets/player/player_controls_overlay.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Same headers the NewPipe spike used to get mpv to play a googlevideo URL.
const _newPipePlaybackHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://www.youtube.com/',
};

class NewPipeMediaKitPlayer extends StatefulWidget {
  const NewPipeMediaKitPlayer({
    super.key,
    required this.watchInfo,
    required this.videoId,
    required this.playbackPosition,
    this.defaultQuality = "720p",
    this.defaultVideoCodec = defaultVideoCodecH264,
    this.isSaved = false,
    this.videoFitMode = "contain",
    this.skipInterval = 10,
    this.isAudioFocusEnabled = true,
    this.subtitleSize = 18.0,
    this.sponsorSegments = const [],
    this.isAutoPipEnabled = true,
    this.preferAdaptivePlayback = false,
  });

  final NewPipeWatchResp watchInfo;
  final String videoId;
  final String defaultQuality;
  final String defaultVideoCodec;
  final int playbackPosition;
  final bool isSaved;
  final String videoFitMode;
  final int skipInterval;
  final bool isAudioFocusEnabled;
  final double subtitleSize;
  final List<SponsorSegment> sponsorSegments;
  final bool isAutoPipEnabled;
  final bool preferAdaptivePlayback;

  @override
  State<NewPipeMediaKitPlayer> createState() => _NewPipeMediaKitPlayerState();
}

class _NewPipeMediaKitPlayerState extends State<NewPipeMediaKitPlayer> {
  // Use global player controller for persistence across navigation
  final GlobalPlayerController _globalPlayer = GlobalPlayerController();

  // Local references for convenience
  Player get _player => _globalPlayer.player;
  VideoController get _videoController => _globalPlayer.videoController;

  PlaybackConfiguration? _currentConfig;
  List<StreamQualityInfo>? _availableQualities;
  String? _currentQualityLabel;
  String? _systemPlayerUrl;
  bool _systemPlayerOpening = false;
  DateTime? _systemPlayerHandoffAt;
  bool _isInitialized = false;
  bool _isInitializing = false; // Guard against concurrent initializations
  bool _isRestoringFromPip = false;
  Duration? _indicatorStart;
  bool _isChangingQuality = false;
  bool _streamRefreshUsed = false;
  late BoxFit _currentFitMode;

  // SponsorBlock
  StreamSubscription<Duration>? _sponsorBlockSubscription;
  final Set<String> _skippedSegments = {};

  // History tracking - throttle updates
  StreamSubscription<Duration>? _historySubscription;
  int _lastSavedPositionSeconds = -1;

  // HLS/DASH adaptive streaming - track video tracks from player
  StreamSubscription<Tracks>? _tracksSubscription;
  List<VideoTrack> _hlsDashVideoTracks = [];
  VideoTrack? _currentVideoTrack;

  // Audio track selection
  List<AudioTrackInfo>? _availableAudioTracks;
  String? _currentAudioTrackId;
  bool _isChangingAudioTrack = false;

  // PiP state tracking - notify Android when playback state changes
  StreamSubscription<bool>? _playingSubscription;

  late final SavedBloc _savedBloc;
  late final WatchBloc _watchBloc;
  late final NewPipePlaybackResolver _resolver;
  late final void Function(String videoId) _indicatorReturn;

  @override
  void initState() {
    super.initState();
    _indicatorReturn = _openIndicatorVideo;
    MediaHubPlayer.instance.bindIndicatorReturn(_indicatorReturn);

    _savedBloc = BlocProvider.of<SavedBloc>(context);
    _watchBloc = BlocProvider.of<WatchBloc>(context);
    _resolver = NewPipePlaybackResolver();
    _currentFitMode = _getBoxFit(widget.videoFitMode);

    // Defer initialization to next frame to handle async operations properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeAsync();
      }
    });
  }

  void _openIndicatorVideo(String videoId) {
    if (!mounted) return;
    for (final video in PlaybackQueue().queue) {
      if (video.id != videoId) continue;
      openQueuedVideo(context, video);
      return;
    }
  }

  /// Async initialization - matches pattern used by other player widgets
  Future<void> _initializeAsync() async {
    // CRITICAL: Prevent concurrent initializations
    // Multiple BlocBuilder rebuilds can trigger initState multiple times
    if (_isInitializing) {
      debugPrint(
          '[NewPipePlayer] Initialization already in progress, skipping');
      return;
    }
    _isInitializing = true;

    try {
      // Check if we're returning from PiP for the same video
      // Only restore if the player is actually in a stable playing state for this video
      _isRestoringFromPip = _globalPlayer.isPlayingVideo(widget.videoId);

      if (_isRestoringFromPip) {
        // Restore from PiP - set initialized immediately since player is already active
        debugPrint(
            '[NewPipePlayer] Restoring from PiP for video ${widget.videoId}');
        _restoreFromPipSync();
      } else {
        // New video - initialize fresh
        debugPrint(
            '[NewPipePlayer] Starting fresh initialization for video ${widget.videoId}');
        await _initializePlayback();
      }
      _setupHistoryListener();
      _setupSponsorBlockListener();
      _setupTracksListener();
      _setupPlayingStateListener();
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void didUpdateWidget(covariant NewPipeMediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video ID changed, reinitialize playback
    if (oldWidget.videoId != widget.videoId) {
      debugPrint(
          '[NewPipePlayer] CRITICAL: Video ID changed from ${oldWidget.videoId} to ${widget.videoId}');
      debugPrint('[NewPipePlayer] IMMEDIATELY stopping old video');

      // Stop both local and global player for the old video. This is awaited
      // inside the async task below so the next open cannot race the previous
      // clear operation.
      unawaited(_globalPlayer.stopAndClear().then((_) {
        if (mounted) {
          _initializeAsync();
        }
      }));

      // Cancel old subscriptions
      _sponsorBlockSubscription?.cancel();
      _historySubscription?.cancel();
      _tracksSubscription?.cancel();
      _playingSubscription?.cancel();
      _skippedSegments.clear();
      _hlsDashVideoTracks = [];
      _currentVideoTrack = null;
      // Reset state - also reset _isInitializing to allow new video init
      setState(() {
        _isInitialized = false;
        _isInitializing = false;
        _isRestoringFromPip = false;
        _lastSavedPositionSeconds = -1;
      });
    }
    // If watchInfo was updated (same videoId but new data), update available qualities
    // This happens when BlocBuilder passes new watchInfo after API response
    else if (oldWidget.watchInfo != widget.watchInfo &&
        widget.watchInfo.videoStreams != null &&
        widget.watchInfo.videoStreams!.isNotEmpty) {
      debugPrint(
          '[NewPipePlayer] watchInfo updated for same video, updating qualities');
      _availableQualities = _loadQualities();
      _availableAudioTracks = NewPipeStreamHelper.getAvailableAudioTracks(
          widget.watchInfo.audioStreams ?? []);
    } else if (oldWidget.defaultVideoCodec != widget.defaultVideoCodec &&
        _isInitialized &&
        !_isInitializing) {
      _availableQualities = _loadQualities();
      final next = _labelForPreferredCodec();
      if (next != null && next != _currentQualityLabel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.defaultVideoCodec == oldWidget.defaultVideoCodec) {
            return;
          }
          unawaited(changeQuality(next));
        });
      }
    }
  }

  /// Keeps the resolution already on screen and moves to the codec chosen
  /// in settings. A fresh open uses the default quality instead.
  String? _labelForPreferredCodec() {
    final qualities = _availableQualities;
    if (qualities == null || qualities.isEmpty) return null;
    final current =
        qualities.where((quality) => quality.label == _currentQualityLabel);
    final currentQuality = current.isEmpty ? null : current.first;
    final pool = currentQuality == null
        ? qualities
        : qualities
            .where((quality) =>
                quality.resolution == currentQuality.resolution &&
                (quality.fps ?? 30) == (currentQuality.fps ?? 30))
            .toList();
    final preference = currentQuality == null
        ? widget.defaultQuality
        : _qualityPreference(currentQuality);
    return NewPipeStreamHelper.findBestMatchingQuality(
      pool.isEmpty ? qualities : pool,
      preference,
      preferredCodec: widget.defaultVideoCodec,
    )?.label;
  }

  String _qualityPreference(StreamQualityInfo quality) {
    var label = '${quality.resolution}p';
    if (quality.fps != null && quality.fps! > 30) {
      label = '$label ${quality.fps}fps';
    }
    return label;
  }

  /// Synchronous restore from PiP - no loading state needed since player is already playing
  void _restoreFromPipSync() {
    // Get available qualities for UI
    _availableQualities = _loadQualities();
    _availableAudioTracks = NewPipeStreamHelper.getAvailableAudioTracks(
        widget.watchInfo.audioStreams ?? []);
    _currentQualityLabel = widget.defaultQuality;
    // Restore audio track from global state if available
    if (_availableAudioTracks != null && _availableAudioTracks!.isNotEmpty) {
      final savedTrackId = _globalPlayer.currentAudioTrackId;
      if (savedTrackId != null &&
          _availableAudioTracks!.any((t) => t.trackId == savedTrackId)) {
        _currentAudioTrackId = savedTrackId;
      } else {
        final originalTrack = _availableAudioTracks!.firstWhere(
          (t) => t.isOriginal && !t.isDubbed && !t.isDescriptive,
          orElse: () => _availableAudioTracks!.first,
        );
        _currentAudioTrackId = originalTrack.trackId;
        _globalPlayer.setCurrentAudioTrackId(_currentAudioTrackId);
      }
    }

    // Resolve config for UI controls
    _currentConfig = _resolveForThisBuild(widget.defaultQuality);

    // Mark as initialized immediately - player is already playing
    _isInitialized = true;

    // Exit PiP mode in background (don't await)
    _globalPlayer.exitPipMode();

    debugPrint('[NewPipePlayer] Restored from PiP successfully (sync)');
  }

  List<StreamQualityInfo> _loadQualities() {
    if (!UbuntuTouch.enabled) {
      return NewPipeStreamHelper.getAvailableQualities(
        widget.watchInfo,
        preferredCodec: widget.defaultVideoCodec,
      );
    }
    return _ubuntuTouchQualities(widget.watchInfo);
  }

  PlaybackConfiguration _resolveForThisBuild(String preferredQuality) {
    if (!UbuntuTouch.enabled) {
      return _resolver.resolve(
        watchResp: widget.watchInfo,
        preferredQuality: preferredQuality,
        preferHighQuality: true,
        preferAdaptive: widget.preferAdaptivePlayback,
        preferredCodec: widget.defaultVideoCodec,
      );
    }
    if (widget.watchInfo.isLive == true) {
      return _resolver.resolve(
        watchResp: widget.watchInfo,
        preferredQuality: preferredQuality,
        preferHighQuality: true,
        preferAdaptive: false,
        preferredCodec: widget.defaultVideoCodec,
      );
    }
    final qualities = _availableQualities ?? _loadQualities();
    // A settings value such as "720p" is not a menu label. Prefer a
    // video-only H.264 or VP9 stream that can go out as one MPD with its
    // m4a. The codec setting picks which of those. Muxed is the fallback
    // when that index is missing. An exact menu label still wins.
    final normalized = preferredQuality.toLowerCase().trim();
    final exact = qualities.any(
      (quality) => quality.label.toLowerCase().trim() == normalized,
    );
    final dash = qualities.where(_dashMenuEntry).toList();
    final muxed =
        qualities.where((quality) => !quality.requiresMerging).toList();
    final pool = exact
        ? qualities
        : (dash.isNotEmpty ? dash : (muxed.isEmpty ? qualities : muxed));
    final match = NewPipeStreamHelper.findBestMatchingQuality(
      pool,
      preferredQuality,
      preferredCodec: widget.defaultVideoCodec,
    );
    final video = match?.videoStream;
    if (video?.url == null || video!.url!.isEmpty) {
      return const PlaybackConfiguration(
        sourceType: MediaSourceType.progressive,
        qualityLabel: 'Unknown',
      );
    }
    final subtitles = widget.watchInfo.subtitles ?? [];
    if (match!.requiresMerging) {
      return PlaybackConfiguration(
        sourceType: MediaSourceType.merging,
        qualityLabel: match.label,
        videoUrl: video.url,
        audioUrl: match.audioStream?.url,
        subtitles: subtitles,
      );
    }
    return PlaybackConfiguration(
      sourceType: MediaSourceType.progressive,
      qualityLabel: match.label,
      videoUrl: video.url,
      subtitles: subtitles,
    );
  }

  List<StreamQualityInfo> _ubuntuTouchQualities(NewPipeWatchResp watch) {
    final qualities = <StreamQualityInfo>[];
    final seen = <String>{};
    final audio =
        NewPipeStreamHelper.getBestAudioStream(watch.audioStreams ?? []);

    void add(NewPipeVideoStream stream, {required bool merging}) {
      if (stream.url == null || stream.url!.isEmpty) return;
      if (_codecFamily(stream) == 'av1') return;
      final height = _parseHeight(stream.resolution);
      if (height == null) return;
      var label = stream.resolution ?? 'Unknown';
      if (stream.fps != null && stream.fps! > 30) {
        label = '$label ${stream.fps}fps';
      }
      final family = _codecFamily(stream);
      final codecName = family == 'other'
          ? (stream.codec ?? stream.format ?? 'video')
          : videoCodecDisplayName(family);
      label = '$label $codecName';
      if (!seen.add(label)) return;
      qualities.add(StreamQualityInfo(
        label: label,
        resolution: height,
        fps: stream.fps,
        format: stream.format,
        requiresMerging: merging,
        isVideoOnly: merging,
        videoStream: stream,
        audioStream: merging ? audio : null,
      ));
    }

    // Muxed streams share labels with video-only ones ("360p H.264").
    // Add them first so the duplicate video-only entry is dropped. A higher
    // video-only entry stays, and its label does not say "no audio": the
    // handoff writes the m4a into the same MPD. `requiresMerging` is what
    // keeps StreamQualityInfo.displayLabel from appending that suffix.
    for (final stream in watch.videoStreams ?? const <NewPipeVideoStream>[]) {
      add(stream, merging: false);
    }
    for (final stream in watch.videoOnlyStreams ?? const <NewPipeVideoStream>[]) {
      add(stream, merging: true);
    }
    qualities.sort((a, b) {
      final byQuality = a.compareTo(b);
      if (byQuality != 0) return byQuality;
      return _codecRank(_codecFamily(a.videoStream!))
          .compareTo(_codecRank(_codecFamily(b.videoStream!)));
    });
    return qualities;
  }

  int? _parseHeight(String? resolution) {
    final match = RegExp(r'(\d+)').firstMatch(resolution ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _codecFamily(NewPipeVideoStream stream) {
    return videoCodecFamily(codec: stream.codec, format: stream.format);
  }

  int _codecRank(String family) {
    return videoCodecRank(family, widget.defaultVideoCodec);
  }

  String? _codecForLabel(String label) {
    for (final quality in _availableQualities ?? const <StreamQualityInfo>[]) {
      if (quality.label == label) {
        return quality.videoStream?.codec ?? quality.videoStream?.format;
      }
    }
    return null;
  }

  Future<void> _initializePlayback() async {
    try {
      // If global player was playing a different video (e.g., in PiP), stop it first
      if (_globalPlayer.hasActivePlayer &&
          _globalPlayer.currentVideoId != widget.videoId) {
        debugPrint(
            '[NewPipePlayer] Stopping previous video ${_globalPlayer.currentVideoId} to play ${widget.videoId}');
        await _globalPlayer.stopAndClear();
      }

      // Check mounted after async operation
      if (!mounted) {
        debugPrint(
            '[NewPipePlayer] Widget disposed during initialization (after stopAndClear)');
        return;
      }

      // Ensure global player is initialized before use
      await _globalPlayer.ensureInitialized();

      // Check mounted after async operation
      if (!mounted) {
        debugPrint(
            '[NewPipePlayer] Widget disposed during initialization (after ensureInitialized)');
        return;
      }

      // STRICT: Enforce that we're about to play the correct video
      // This is a critical safety check to prevent video mismatches
      await _globalPlayer.enforceVideoId(widget.videoId);

      // Check mounted after async operation
      if (!mounted) {
        debugPrint(
            '[NewPipePlayer] Widget disposed during initialization (after enforceVideoId)');
        return;
      }

      // Get available qualities
      _availableQualities = _loadQualities();

      // Get available audio tracks
      _availableAudioTracks = NewPipeStreamHelper.getAvailableAudioTracks(
          widget.watchInfo.audioStreams ?? []);
      // Restore audio track from global state if available, otherwise set default
      if (_availableAudioTracks != null && _availableAudioTracks!.isNotEmpty) {
        final savedTrackId = _globalPlayer.currentAudioTrackId;
        if (savedTrackId != null &&
            _availableAudioTracks!.any((t) => t.trackId == savedTrackId)) {
          _currentAudioTrackId = savedTrackId;
        } else {
          // First try to find an explicitly original, non-dubbed track
          final originalTrack = _availableAudioTracks!.firstWhere(
            (t) => t.isOriginal && !t.isDubbed && !t.isDescriptive,
            orElse: () => _availableAudioTracks!.first,
          );
          _currentAudioTrackId = originalTrack.trackId;
          _globalPlayer.setCurrentAudioTrackId(_currentAudioTrackId);
        }
      }

      // Determine initial quality
      String targetQuality = widget.defaultQuality;

      // Check if preferred quality is available
      final hasPreferredQuality =
          _availableQualities?.any((q) => q.label == targetQuality) ?? false;
      if (!hasPreferredQuality && (_availableQualities?.isNotEmpty ?? false)) {
        // Use closest available quality
        targetQuality = _findClosestQuality(targetQuality);
      }

      _currentQualityLabel = targetQuality;

      // Resolve playback configuration
      _currentConfig = _resolveForThisBuild(targetQuality);

      // For HLS/DASH, set initial quality label to "Auto" since adaptive streaming handles quality
      final isAdaptive = _currentConfig!.sourceType == MediaSourceType.hls ||
          _currentConfig!.sourceType == MediaSourceType.dash;
      if (isAdaptive) {
        _currentQualityLabel = 'Auto';
        // Clear video stream qualities - will be populated by tracks listener
        _availableQualities = null;
      }

      debugPrint('=== MediaKit Playback Debug ===');
      debugPrint('Source type: ${_currentConfig!.sourceType}');
      debugPrint('Quality: ${_currentConfig!.qualityLabel}');
      print(
        'gastube: stream=${_currentConfig!.qualityLabel} '
        'pref=${widget.defaultVideoCodec} '
        'source=${_currentConfig!.sourceType} '
        'codecs=${_availableQualities?.map((q) => '${q.label}:${q.videoStream?.codec ?? q.videoStream?.format}').join(',')}',
      );
      debugPrint('Video URL: ${_currentConfig!.videoUrl}');
      debugPrint('Audio URL: ${_currentConfig!.audioUrl}');
      debugPrint('Manifest URL: ${_currentConfig!.manifestUrl}');
      debugPrint('Is valid: ${_currentConfig!.isValid}');

      if (!_currentConfig!.isValid) {
        _showError('No valid video stream available');
        return;
      }

      // Update global player controller state for PiP support
      // IMPORTANT: Set video ID BEFORE setupMediaSource so notification can be updated
      final openedUrl =
          _currentConfig!.videoUrl ?? _currentConfig!.manifestUrl;
      _globalPlayer.setCurrentVideoId(widget.videoId, videoUrl: openedUrl);

      // Setup media source
      _indicatorStart ??=
          MediaHubPlayer.instance.takeReturnPosition(widget.videoId);
      await _setupMediaSource(
        _currentConfig!,
        startPosition:
            _indicatorStart ?? Duration(seconds: widget.playbackPosition),
      );

      // Check mounted after async operation
      if (!mounted) {
        debugPrint(
            '[NewPipePlayer] Widget disposed during initialization (after setupMediaSource)');
        return;
      }

      // Enable auto-PiP based on settings (only on Android)
      await _globalPlayer.enableAutoPip(widget.isAutoPipEnabled);

      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing playback: $e');
      if (mounted) {
        _showError('Failed to initialize video playback');
      }
    }
  }

  void _reportHardwareDecoder() {
    if (!UbuntuTouch.enabled) return;
    unawaited(() async {
      var softwareReads = 0;
      for (var attempt = 0; attempt < 8; attempt++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        try {
          final requested =
              await (_player.platform as dynamic).getProperty('hwdec');
          final current =
              await (_player.platform as dynamic).getProperty('hwdec-current');
          final decoder = await (_player.platform as dynamic)
              .getProperty('current-tracks/video/decoder-desc');
          print(
            'gastube: hwdec=$requested hwdec-current=$current decoder=$decoder',
          );
          if (decoder is String &&
              (decoder.contains('h264_hybris') || decoder.contains('vp9_hybris'))) {
            print('gastube: decode=mediacodec');
            return;
          }
          if (decoder is String && decoder.contains('vp9 (')) {
            print('gastube: decode=software-vp9');
            return;
          }
          if (current == 'no' && decoder is String && decoder.contains('h264 (')) {
            softwareReads++;
            if (softwareReads >= 2) {
              print('gastube: decode=software-h264');
              return;
            }
          }
        } catch (e) {
          print('gastube: hwdec query failed: $e');
          return;
        }
      }
      print('gastube: decode=mediacodec-unopened');
      await _refreshRejectedStream();
    }());
  }

  /// The last 0:00 stop was a googlevideo URL answering 403. Changing quality
  /// reused that same extract. Drop it and open the video once more.
  Future<void> _refreshRejectedStream() async {
    if (!UbuntuTouch.enabled || _streamRefreshUsed || !mounted) return;
    final audioUrl =
        _selectedTrackAudioUrl() ?? _currentConfig?.audioUrl ?? _currentConfig?.videoUrl;
    final rejected = MediaHubPlayer.instance.urlWasRejected(audioUrl);
    final stuck = _player.state.playing &&
        _player.state.position < const Duration(seconds: 1);
    if (!rejected && !stuck) return;
    _streamRefreshUsed = true;
    final reason = rejected ? '403' : 'unopened';
    print('gastube: stream refresh reason=$reason id=${widget.videoId}');
    try {
      await NewPipeChannel.forgetStreamInfo(widget.videoId);
      final fresh = await NewPipeChannel.getStreamInfoFast(widget.videoId);
      if (!mounted) return;
      _availableQualities = _ubuntuTouchQualities(fresh);
      _availableAudioTracks = NewPipeStreamHelper.getAvailableAudioTracks(
        fresh.audioStreams ?? [],
      );
      final label = _currentQualityLabel ?? widget.defaultQuality;
      final start = _player.state.position >= const Duration(seconds: 1)
          ? _player.state.position
          : (_indicatorStart ?? Duration(seconds: widget.playbackPosition));
      await _setupMediaSource(
        _resolveForThisBuild(label),
        startPosition: start,
        updateNotification: false,
        fastSwitch: true,
      );
      if (!mounted) return;
      _currentConfig = _resolveForThisBuild(label);
      _currentQualityLabel = _currentConfig?.qualityLabel ?? label;
    } catch (error) {
      print('gastube: stream refresh failed error=$error');
    }
  }

  Future<void> _setupMediaSource(
    PlaybackConfiguration config, {
    Duration startPosition = Duration.zero,
    bool play = true,
    bool updateNotification = true,
    bool fastSwitch = false,
  }) async {
    try {
      final dashQuality = _qualityForLabel(config.qualityLabel);
      if (UbuntuTouch.enabled &&
          widget.watchInfo.isLive != true &&
          dashQuality != null &&
          _dashMenuEntry(dashQuality)) {
        final handed = await _openDashInSystemPlayer(config);
        if (handed || !mounted) return;
        final muxed = _muxedHttpUrl();
        if (muxed != null) {
          final handedMuxed = await _openMuxedInSystemPlayer(muxed);
          if (handedMuxed || !mounted) return;
        }
      }
      if (UbuntuTouch.enabled &&
          config.sourceType == MediaSourceType.progressive &&
          _isHttpPlaybackUrl(config.videoUrl)) {
        final handed = await _openMuxedInSystemPlayer(config.videoUrl!);
        if (handed || !mounted) return;
      }
      if (mounted && _systemPlayerUrl != null) {
        setState(() => _systemPlayerUrl = null);
      }
      if (UbuntuTouch.enabled) {
        await (_player.platform as dynamic).setProperty('ao', 'pulse');
        await selectUbuntuTouchDecoder(
          _player,
          codec: _codecForLabel(config.qualityLabel),
        );
      }
      final isAdaptive = config.sourceType == MediaSourceType.hls ||
          config.sourceType == MediaSourceType.dash;

      switch (config.sourceType) {
        case MediaSourceType.progressive:
          // Muxed stream (has audio, ≤360p). YouTube's embedded track is
          // often the viewer's language, so replace it with the menu's track.
          await _player.open(
            Media(config.videoUrl!, httpHeaders: _newPipePlaybackHeaders),
            play: false,
          );
          debugPrint('Opened progressive stream');
          if (!mounted) return;
          await _applySelectedAudioTrack();
          _globalPlayer.noteBackgroundAudio(
            url: _selectedTrackAudioUrl() ?? config.videoUrl,
            headers: _newPipePlaybackHeaders,
          );
          break;

        case MediaSourceType.merging:
          // Separate video + audio (>360p)
          final audioUrl =
              _selectedTrackAudioUrl() ?? config.audioUrl ?? _selectMediumQualityAudio();

          // First open video - don't wait for ready here, just open
          await _player.open(
            Media(config.videoUrl!, httpHeaders: _newPipePlaybackHeaders),
            play: false,
          );
          debugPrint('Opening merging stream');

          // Check mounted after async operation
          if (!mounted) return;

          if (audioUrl != null) {
            // Register headers for this URI before mpv loads the external track.
            Media(audioUrl, httpHeaders: _newPipePlaybackHeaders);
            try {
              await _player.setAudioTrack(
                AudioTrack.uri(audioUrl),
              );
              debugPrint('Opened video + audio (${config.qualityLabel})');
              debugPrint('Video: ${config.videoUrl?.substring(0, 80)}...');
              debugPrint('Audio: ${audioUrl.substring(0, 80)}...');
            } catch (e) {
              debugPrint('Error setting audio track: $e');
            }
          } else {
            debugPrint('Warning: No audio URL available');
          }
          _globalPlayer.noteBackgroundAudio(
            url: audioUrl,
            headers: _newPipePlaybackHeaders,
          );

          // Check mounted after async operation
          if (!mounted) return;
          break;

        case MediaSourceType.hls:
          // HLS stream - fast initialization, no separate wait needed
          await _player.open(
            Media(config.manifestUrl!, httpHeaders: _newPipePlaybackHeaders),
            play: false,
          );
          debugPrint('Opened HLS stream');
          _globalPlayer.noteBackgroundAudio(
            url: config.manifestUrl,
            headers: _newPipePlaybackHeaders,
          );
          break;

        case MediaSourceType.dash:
          // DASH manifest - fast initialization, no separate wait needed
          await _player.open(
            Media(config.manifestUrl!, httpHeaders: _newPipePlaybackHeaders),
            play: false,
          );
          debugPrint('Opened DASH stream');
          _globalPlayer.noteBackgroundAudio(
            url: config.manifestUrl,
            headers: _newPipePlaybackHeaders,
          );
          break;
      }

      // Check mounted after switch block
      if (!mounted) return;
      _reportHardwareDecoder();

      // Setup subtitles asynchronously - don't block playback
      if (config.subtitles.isNotEmpty) {
        _setupSubtitlesAsync(config.subtitles);
      }

      // For HLS/DASH, start playback immediately - they handle buffering internally
      // For progressive/merging, wait for duration to be available
      if (!isAdaptive) {
        await _waitForPlayerReady(
          timeout: fastSwitch
              ? const Duration(milliseconds: 800)
              : const Duration(seconds: 2),
        );
        if (!mounted) return;
      }

      if (startPosition > Duration.zero && !config.isLive) {
        await seekUbuntuTouchResume(_player, startPosition);
        debugPrint('Seeked to resume position: ${startPosition.inSeconds}s');
        if (!mounted) return;
      }

      if (play) {
        await _player.play();
      }

      // Notify native side that video is playing (for auto-PiP)
      await _globalPlayer.updatePlaybackStateForPip();

      if (updateNotification) {
        // Update media notification for background playback controls.
        await _globalPlayer.updateMediaNotification(
          title: widget.watchInfo.title ?? 'Video',
          artist: widget.watchInfo.uploaderName ?? 'Unknown',
          thumbnailUrl: widget.watchInfo.thumbnailUrl,
          duration: widget.watchInfo.duration != null
              ? Duration(seconds: widget.watchInfo.duration!)
              : null,
        );
      }

      // Check mounted after play
      if (!mounted) return;

      debugPrint('Started playback');
    } catch (e) {
      debugPrint('Error setting up media source: $e');
      if (mounted) {
        _showError('Failed to load video');
      }
    }
  }

  /// Setup subtitles asynchronously to not block playback
  void _setupSubtitlesAsync(List subtitles) {
    Future.microtask(() {
      for (var subtitle in subtitles) {
        if (subtitle.url != null && subtitle.url!.isNotEmpty) {
          try {
            _player.setSubtitleTrack(
              SubtitleTrack.uri(subtitle.url!,
                  title: subtitle.languageCode ?? 'Unknown'),
            );
            debugPrint('Added subtitle: ${subtitle.languageCode}');
          } catch (e) {
            debugPrint('Failed to add subtitle: $e');
          }
        }
      }
    });
  }

  bool _isHttpPlaybackUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _dashMenuEntry(StreamQualityInfo quality) {
    return quality.requiresMerging &&
        ubuntuTouchDashVideo(quality.videoStream);
  }

  StreamQualityInfo? _qualityForLabel(String label) {
    for (final quality in _availableQualities ?? const <StreamQualityInfo>[]) {
      if (quality.label == label) return quality;
    }
    return null;
  }

  String? _muxedHttpUrl() {
    for (final quality in _availableQualities ?? const <StreamQualityInfo>[]) {
      if (quality.requiresMerging) continue;
      final url = quality.videoStream?.url;
      if (_isHttpPlaybackUrl(url)) return url;
    }
    return null;
  }

  NewPipeAudioStream? _handoffAudio() {
    final tracks = _availableAudioTracks;
    final trackId = _currentAudioTrackId;
    if (tracks != null && trackId != null) {
      for (final track in tracks) {
        if (track.trackId != trackId) continue;
        final ready = track.streams.where(ubuntuTouchDashAudio).toList();
        if (ready.isEmpty) break;
        ready.sort(
          (a, b) => (b.averageBitrate ?? b.bitrate ?? 0)
              .compareTo(a.averageBitrate ?? a.bitrate ?? 0),
        );
        return ready.first;
      }
    }
    final original = (widget.watchInfo.audioStreams ?? const <NewPipeAudioStream>[])
        .where(
          (stream) =>
              ubuntuTouchDashAudio(stream) &&
              stream.isOriginal &&
              !stream.isDubbed &&
              !stream.isDescriptive,
        )
        .toList();
    if (original.isEmpty) return null;
    original.sort(
      (a, b) => (b.averageBitrate ?? b.bitrate ?? 0)
          .compareTo(a.averageBitrate ?? a.bitrate ?? 0),
    );
    return original.first;
  }

  /// Video-only H.264 or VP9 plus its m4a, as one local MPD. A failure
  /// leaves the muxed address as the handoff.
  Future<bool> _openDashInSystemPlayer(PlaybackConfiguration config) async {
    final video = _qualityForLabel(config.qualityLabel)?.videoStream;
    final audio = _handoffAudio();
    if (!ubuntuTouchDashVideo(video) || !ubuntuTouchDashAudio(audio)) {
      return false;
    }
    final handoffAt = _systemPlayerHandoffAt;
    if (handoffAt != null &&
        DateTime.now().difference(handoffAt) < const Duration(seconds: 4)) {
      print('gastube: system player handoff skipped reason=recent');
      return true;
    }
    _systemPlayerHandoffAt = DateTime.now();
    final path = await writeUbuntuTouchDashMpd(
      videoId: widget.videoId,
      video: video!,
      audio: audio!,
    );
    if (path == null) {
      _systemPlayerHandoffAt = null;
      print('gastube: dash handoff failed reason=mpd');
      return false;
    }
    _globalPlayer.forgetBackgroundAudio();
    try {
      await _player.pause();
    } catch (error) {
      print('gastube: system player pause error=$error');
    }
    await MediaHubPlayer.instance.stop();
    await systemPlayerStoredPosition(path);
    final opened = await openInSystemPlayer(path: path, audioOnly: false);
    print(
      'gastube: dash handoff ok=${opened.ok} height=${video.height} '
      'itag=${video.itag} codec=${video.codec}',
    );
    if (opened.ok && mounted) {
      setState(() => _systemPlayerUrl = path);
    }
    return opened.ok;
  }

  /// Muxed YouTube addresses play in the system player.
  Future<bool> _openMuxedInSystemPlayer(String url) async {
    final handoffAt = _systemPlayerHandoffAt;
    if (handoffAt != null &&
        DateTime.now().difference(handoffAt) < const Duration(seconds: 4)) {
      print('gastube: system player handoff skipped reason=recent');
      return true;
    }
    _systemPlayerHandoffAt = DateTime.now();
    _globalPlayer.forgetBackgroundAudio();
    try {
      await _player.pause();
    } catch (error) {
      print('gastube: system player pause error=$error');
    }
    await MediaHubPlayer.instance.stop();
    await systemPlayerStoredPosition(url);
    final opened = await openUrlInSystemPlayer(url);
    print(
      'gastube: system player handoff ok=${opened.ok} '
      'message=${opened.message}',
    );
    if (opened.ok && mounted) {
      setState(() => _systemPlayerUrl = url);
    }
    return opened.ok;
  }

  Future<void> _reopenSystemPlayer() async {
    final url = _systemPlayerUrl;
    if (url == null || _systemPlayerOpening) return;
    _systemPlayerOpening = true;
    try {
      final config = _currentConfig;
      final dashQuality = config == null
          ? null
          : _qualityForLabel(config.qualityLabel);
      if (config != null &&
          dashQuality != null &&
          _dashMenuEntry(dashQuality)) {
        final handed = await _openDashInSystemPlayer(config);
        if (handed) return;
        final muxed = _muxedHttpUrl();
        if (muxed != null) {
          await _openMuxedInSystemPlayer(muxed);
          return;
        }
      }
      await _openMuxedInSystemPlayer(url);
    } finally {
      _systemPlayerOpening = false;
    }
  }

  /// URL of the track the menu is showing, when one is selected.
  String? _selectedTrackAudioUrl() {
    final tracks = _availableAudioTracks;
    final trackId = _currentAudioTrackId;
    if (tracks == null || trackId == null) return null;
    for (final track in tracks) {
      if (track.trackId != trackId) continue;
      final url = track.bestStream?.url;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  Future<void> _applySelectedAudioTrack() async {
    final audioUrl = _selectedTrackAudioUrl();
    if (audioUrl == null) return;
    Media(audioUrl, httpHeaders: _newPipePlaybackHeaders);
    try {
      await _player.setAudioTrack(AudioTrack.uri(audioUrl));
      debugPrint('Applied selected audio track');
    } catch (e) {
      debugPrint('Error setting selected audio track: $e');
    }
  }

  /// Select a medium-quality ORIGINAL audio stream (around 128kbps)
  /// Prioritizes original audio over dubbed/translated versions
  /// Returns fresh URL each time - needed because YouTube URLs expire
  String? _selectMediumQualityAudio() {
    final audioStreams = widget.watchInfo.audioStreams ?? [];
    if (audioStreams.isEmpty) return null;

    // Debug: Log all audio streams with URL-based detection
    debugPrint('=== Audio Stream Detection ===');
    for (var audio in audioStreams) {
      debugPrint(
          '  - ${audio.quality} | ${audio.format} | type: ${audio.audioTrackType ?? "null"} | isOriginal: ${audio.isOriginal} | isDubbed: ${audio.isDubbed}');
    }
    debugPrint('==============================');

    // Filter to only original audio streams (not dubbed or descriptive)
    // Now also checks URL xtags for dubbed indicators when audioTrackType is null
    final originalStreams = audioStreams.where((audio) {
      if (audio.url == null || audio.url!.isEmpty) return false;
      return audio.isOriginal;
    }).toList();

    debugPrint(
        'Audio filtering: ${originalStreams.length} original streams found out of ${audioStreams.length} total');

    // If no original streams found, fall back to all streams (excluding descriptive)
    final candidateStreams = originalStreams.isNotEmpty
        ? originalStreams
        : audioStreams.where((audio) {
            if (audio.url == null || audio.url!.isEmpty) return false;
            return !audio.isDescriptive;
          }).toList();

    if (candidateStreams.isEmpty) {
      // Last resort: use any available stream
      final anyValid = audioStreams.firstWhere(
        (audio) => audio.url != null && audio.url!.isNotEmpty,
        orElse: () => audioStreams.first,
      );
      debugPrint(
          'No suitable audio found, using fallback: ${anyValid.quality ?? "Unknown"}');
      return anyValid.url;
    }

    // Sort by quality
    final sorted = NewPipeStreamHelper.sortAudioStreams(candidateStreams);

    // Target medium quality (around 128kbps)
    // Find audio stream closest to 128kbps bitrate
    const targetBitrate = 128;
    NewPipeAudioStream? selectedAudio = sorted.first;
    int smallestDiff = double.maxFinite.toInt();

    for (var audio in sorted) {
      final bitrate = audio.averageBitrate ?? 0;
      final diff = (bitrate - targetBitrate).abs();

      if (diff < smallestDiff) {
        smallestDiff = diff;
        selectedAudio = audio;
      }
    }

    debugPrint(
        'Selected audio: ${selectedAudio?.quality ?? "Unknown"} | Bitrate: ${selectedAudio?.averageBitrate ?? 0}kbps | Format: ${selectedAudio?.format ?? "Unknown"} | TrackType: ${selectedAudio?.audioTrackType ?? "null"} | isOriginal: ${selectedAudio?.isOriginal} | isDubbed: ${selectedAudio?.isDubbed} | Locale: ${selectedAudio?.audioLocale ?? "N/A"}');
    return selectedAudio?.url;
  }

  /// Wait for the player to be ready (duration > 0) with timeout
  /// Uses stream-based waiting for efficiency instead of polling
  Future<void> _waitForPlayerReady(
      {Duration timeout = const Duration(seconds: 3)}) async {
    // If already ready, return immediately
    if (_player.state.duration > Duration.zero) {
      debugPrint(
          '[Player] Player already ready, duration: ${_player.state.duration}');
      return;
    }

    // Use Completer with stream listening for efficient waiting
    final completer = Completer<void>();
    StreamSubscription<Duration>? subscription;

    // Set up timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint(
            '[Player] Timeout waiting for player ready, proceeding anyway');
        subscription?.cancel();
        completer.complete();
      }
    });

    // Listen for duration changes
    subscription = _player.stream.duration.listen((duration) {
      if (duration > Duration.zero && !completer.isCompleted) {
        debugPrint('[Player] Player ready, duration: $duration');
        timer.cancel();
        subscription?.cancel();
        completer.complete();
      }
    });

    await completer.future;
  }

  String _findClosestQuality(String targetQuality) {
    if (_availableQualities == null || _availableQualities!.isEmpty) {
      return targetQuality;
    }

    final qualities = _availableQualities!;
    // Settings such as "720p" are not a menu label. On Ubuntu Touch that
    // search prefers a video-only H.264 or VP9 stream with a DASH index.
    // The codec setting picks which. Muxed is what remains when the video
    // has no such stream.
    final List<StreamQualityInfo> pool;
    if (!UbuntuTouch.enabled) {
      pool = qualities;
    } else {
      final dash = qualities.where(_dashMenuEntry).toList();
      final muxed =
          qualities.where((quality) => !quality.requiresMerging).toList();
      pool = dash.isNotEmpty
          ? dash
          : (muxed.isEmpty ? qualities : muxed);
    }
    return NewPipeStreamHelper.findBestMatchingQuality(
          pool,
          targetQuality,
          preferredCodec: widget.defaultVideoCodec,
        )?.label ??
        targetQuality;
  }

  void _setupHistoryListener() {
    // Cancel any existing subscription
    _historySubscription?.cancel();

    // Update history every 15 seconds. This keeps resume position fresh without
    // doing database work too often while the decoder is already busy.
    _historySubscription = _player.stream.position.listen((position) {
      final currentSeconds = position.inSeconds;
      // Only update when we cross the boundary AND haven't already saved this position.
      if (currentSeconds > 0 &&
          currentSeconds % 15 == 0 &&
          currentSeconds != _lastSavedPositionSeconds) {
        _lastSavedPositionSeconds = currentSeconds;
        _updateVideoHistory();
      }
    });
  }

  /// Setup listener for HLS/DASH video tracks
  /// This allows quality selection for adaptive streaming
  void _setupTracksListener() {
    _tracksSubscription?.cancel();
    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      if (!mounted) return;

      // Only process if using HLS/DASH
      final isAdaptive = _currentConfig?.sourceType == MediaSourceType.hls ||
          _currentConfig?.sourceType == MediaSourceType.dash;

      if (isAdaptive && tracks.video.isNotEmpty) {
        debugPrint(
            '[NewPipePlayer] HLS/DASH tracks available: ${tracks.video.length} video tracks');

        // Filter valid video tracks (non-empty id and resolution info)
        final validTracks = tracks.video.where((track) {
          // VideoTrack.auto() has empty id, keep it
          // Other tracks should have resolution info
          return track.id.isEmpty || (track.w != null && track.h != null);
        }).toList();

        // Sort by resolution (highest first), keeping auto at the beginning
        validTracks.sort((a, b) {
          if (a.id.isEmpty) return -1; // auto goes first
          if (b.id.isEmpty) return 1;
          final aRes = (a.h ?? 0);
          final bRes = (b.h ?? 0);
          return bRes.compareTo(aRes); // Higher resolution first
        });

        setState(() {
          _hlsDashVideoTracks = validTracks;
          // Get current track
          _currentVideoTrack = _player.state.track.video;

          // Update quality label based on current track
          if (_currentVideoTrack != null) {
            _currentQualityLabel = _getTrackQualityLabel(_currentVideoTrack!);
          }

          // Build quality list for UI from adaptive tracks
          _availableQualities = _buildQualitiesFromTracks(validTracks);
        });

        debugPrint(
            '[NewPipePlayer] Available HLS/DASH qualities: ${_availableQualities?.map((q) => q.label).join(", ")}');
      }
    });
  }

  /// Setup listener to track playing state changes for PiP
  void _setupPlayingStateListener() {
    _playingSubscription?.cancel();
    _playingSubscription = _player.stream.playing.listen((isPlaying) {
      // Notify Android about playback state changes for auto-PiP
      _globalPlayer.updatePlaybackStateForPip();
    });
  }

  /// Build StreamQualityInfo list from VideoTrack list (for HLS/DASH)
  List<StreamQualityInfo> _buildQualitiesFromTracks(List<VideoTrack> tracks) {
    return tracks.map((track) {
      final label = _getTrackQualityLabel(track);
      final resolution = track.h ?? 0;

      return StreamQualityInfo(
        label: label,
        resolution: resolution,
        fps: track.fps?.toInt(),
        format: null,
        requiresMerging: false, // HLS/DASH handles this internally
        isVideoOnly: false, // HLS/DASH includes audio
        videoStream: null, // Not applicable for adaptive
        audioStream: null,
      );
    }).toList();
  }

  /// Get quality label from VideoTrack
  String _getTrackQualityLabel(VideoTrack track) {
    if (track.id.isEmpty) {
      return 'Auto';
    }

    final height = track.h ?? 0;
    final fps = track.fps?.toInt();

    if (height == 0) {
      return track.title ?? track.id;
    }

    // Format as "1080p" or "1080p60" for high frame rate
    if (fps != null && fps > 30) {
      return '${height}p$fps';
    }
    return '${height}p';
  }

  /// Find VideoTrack by quality label
  VideoTrack? _findTrackByQualityLabel(String qualityLabel) {
    if (qualityLabel == 'Auto') {
      return VideoTrack.auto();
    }

    for (final track in _hlsDashVideoTracks) {
      if (_getTrackQualityLabel(track) == qualityLabel) {
        return track;
      }
    }
    return null;
  }

  void _setupSponsorBlockListener() {
    if (widget.sponsorSegments.isEmpty) return;

    _sponsorBlockSubscription = _player.stream.position.listen((position) {
      final currentSeconds = position.inSeconds.toDouble() +
          (position.inMilliseconds % 1000) / 1000.0;

      for (final segment in widget.sponsorSegments) {
        // Check if we're within this segment and haven't skipped it yet
        if (segment.containsPosition(currentSeconds) &&
            !_skippedSegments.contains(segment.uuid)) {
          _skippedSegments.add(segment.uuid);

          // Seek to end of segment
          final seekPosition = Duration(
            milliseconds: (segment.endTime * 1000).round(),
          );
          _player.seek(seekPosition);

          // Show toast notification
          _showToast('Skipped ${segment.categoryDisplayName}');
          debugPrint(
              '[SponsorBlock] Skipped ${segment.category} segment: ${segment.startTime}s - ${segment.endTime}s');
          break;
        }
      }
    });
  }

  Future<void> changeQuality(String newQualityLabel) async {
    if (_currentQualityLabel == newQualityLabel) return;

    setState(() {
      _isChangingQuality = true;
    });

    try {
      // Check if we're using HLS/DASH - use track selection instead of reopening stream
      final isAdaptive = _currentConfig?.sourceType == MediaSourceType.hls ||
          _currentConfig?.sourceType == MediaSourceType.dash;

      if (isAdaptive && _hlsDashVideoTracks.isNotEmpty) {
        // HLS/DASH quality change - use setVideoTrack
        await _changeQualityAdaptive(newQualityLabel);
      } else {
        // Progressive/Merging quality change - reopen stream
        await _changeQualityProgressive(newQualityLabel);
      }
    } catch (e) {
      debugPrint('Error changing quality: $e');
      _showError('Failed to change quality');
      setState(() {
        _isChangingQuality = false;
      });
    }
  }

  /// Change quality for HLS/DASH streams using setVideoTrack
  Future<void> _changeQualityAdaptive(String newQualityLabel) async {
    final targetTrack = _findTrackByQualityLabel(newQualityLabel);

    if (targetTrack == null) {
      debugPrint(
          '[NewPipePlayer] Could not find track for quality: $newQualityLabel');
      _showError('Quality not available');
      setState(() {
        _isChangingQuality = false;
      });
      return;
    }

    debugPrint(
        '[NewPipePlayer] Changing HLS/DASH quality to: $newQualityLabel (track: ${targetTrack.id})');

    // Set the video track
    await _player.setVideoTrack(targetTrack);

    if (!mounted) return;

    setState(() {
      _currentVideoTrack = targetTrack;
      _currentQualityLabel = newQualityLabel;
      _isChangingQuality = false;
    });

    debugPrint('[NewPipePlayer] HLS/DASH quality changed to: $newQualityLabel');
  }

  /// Change quality for progressive/merging streams (requires reopening stream)
  Future<void> _changeQualityProgressive(String newQualityLabel) async {
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;

    // Resolve new configuration (only video URL will be used, audio stays the same)
    final newConfig = _resolveForThisBuild(newQualityLabel);

    if (!newConfig.isValid) {
      _showError('Quality not available');
      setState(() {
        _isChangingQuality = false;
      });
      return;
    }

    debugPrint('Changing quality to: $newQualityLabel (keeping fixed audio)');

    await _setupMediaSource(
      newConfig,
      startPosition: currentPosition,
      play: wasPlaying,
      updateNotification: false,
      fastSwitch: true,
    );

    setState(() {
      _currentConfig = newConfig;
      _currentQualityLabel = newQualityLabel;
      _isChangingQuality = false;
    });

    debugPrint('Quality changed to: $newQualityLabel');
  }

  /// Change audio track (for multi-track videos like dubbed content)
  Future<void> changeAudioTrack(String newTrackId) async {
    if (_currentAudioTrackId == newTrackId) return;
    if (_availableAudioTracks == null || _availableAudioTracks!.isEmpty) return;

    // Find the target track
    final targetTrack = _availableAudioTracks!.firstWhere(
      (t) => t.trackId == newTrackId,
      orElse: () => _availableAudioTracks!.first,
    );

    // Get the best stream for this track
    final audioStream = targetTrack.bestStream;
    if (audioStream?.url == null) {
      debugPrint(
          '[NewPipePlayer] No valid audio stream for track: $newTrackId');
      _showError('Audio track not available');
      return;
    }

    setState(() {
      _isChangingAudioTrack = true;
    });

    try {
      debugPrint(
          '[NewPipePlayer] Changing audio track to: ${targetTrack.displayName} ($newTrackId)');

      // Set the new audio track
      await _player.setAudioTrack(AudioTrack.uri(audioStream!.url!));
      _globalPlayer.noteBackgroundAudio(
        url: audioStream.url,
        headers: _newPipePlaybackHeaders,
      );

      // Wait for audio to stabilize
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      setState(() {
        _currentAudioTrackId = newTrackId;
        _isChangingAudioTrack = false;
      });

      // Save to global state for persistence across widget rebuilds
      _globalPlayer.setCurrentAudioTrackId(newTrackId);

      _showToast('Audio: ${targetTrack.displayName}');
      debugPrint(
          '[NewPipePlayer] Audio track changed to: ${targetTrack.displayName}');
    } catch (e) {
      debugPrint('[NewPipePlayer] Error changing audio track: $e');
      if (mounted) {
        setState(() {
          _isChangingAudioTrack = false;
        });
        _showError('Failed to change audio track');
      }
    }
  }

  @override
  void dispose() {
    MediaHubPlayer.instance.unbindIndicatorReturn(_indicatorReturn);
    _sponsorBlockSubscription?.cancel();
    _historySubscription?.cancel();
    _tracksSubscription?.cancel();
    _playingSubscription?.cancel();
    _updateVideoHistory();
    // Don't dispose the global player - save state for PiP transition
    // The player will persist and can be restored when returning from PiP
    _globalPlayer.savePlaybackState();
    debugPrint(
        '[NewPipePlayer] Dispose called - saving state for potential PiP');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to react to player duration changes
    // This ensures we show loading until video is actually ready
    return StreamBuilder<Duration>(
      stream: _player.stream.duration,
      initialData: _player.state.duration,
      builder: (context, durationSnapshot) {
        // Show loading only for fresh initialization, not when restoring from PiP
        // Check if player is already active with loaded media to skip loading state
        // A video is "ready" when:
        // 1. ID matches AND
        // 2. Either duration > 0 (metadata loaded) OR position > 0 (has played)
        final duration = durationSnapshot.data ?? Duration.zero;
        final bool playerIsReady = _globalPlayer.currentVideoId ==
                widget.videoId &&
            (duration.inSeconds > 0 || _player.state.position.inSeconds > 0);

        if (!_isInitialized && !playerIsReady) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        // For controls, we need config - but we can still show video without it
        if (_currentConfig == null && !playerIsReady) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        if (_systemPlayerUrl != null) {
          return AspectRatio(
            aspectRatio: _getAspectRatio(),
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: IconButton(
                  iconSize: 72,
                  color: Colors.white,
                  icon: const Icon(Icons.play_circle_fill),
                  onPressed: _reopenSystemPlayer,
                ),
              ),
            ),
          );
        }

        return AspectRatio(
          aspectRatio: _getAspectRatio(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(
                controller: _videoController,
                controls: (state) {
                  return _buildCustomControls(state);
                },
                fit: _currentFitMode,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: TextStyle(
                    fontSize: widget.subtitleSize,
                    color: Colors.white,
                    backgroundColor: const Color(0x99000000),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                ),
              ),
              // Buffering indicator overlay
              StreamBuilder<bool>(
                stream: _player.stream.buffering,
                initialData: false,
                builder: (context, snapshot) {
                  final isBuffering = snapshot.data ?? false;
                  // Show loading for buffering, quality change, or audio track change
                  if (!isBuffering &&
                      !_isChangingQuality &&
                      !_isChangingAudioTrack) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          if (_isChangingQuality) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Changing quality...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ] else if (_isChangingAudioTrack) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Changing audio track...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomControls(VideoState state) {
    return PlayerControlsOverlay(
      player: _player,
      videoState: state,
      availableQualities: _availableQualities,
      currentQuality: _currentQualityLabel,
      onQualityChanged: changeQuality,
      subtitles: _currentConfig?.subtitles ?? [],
      skipInterval: widget.skipInterval,
      isLive: widget.watchInfo.isLive == true,
      currentFitMode: _currentFitMode,
      onFitModeChanged: _onFitModeChanged,
      availableAudioTracks: _availableAudioTracks,
      currentAudioTrackId: _currentAudioTrackId,
      onAudioTrackChanged: changeAudioTrack,
      isInitializing: !_isInitialized,
    );
  }

  void _onFitModeChanged(BoxFit newFitMode) {
    setState(() {
      _currentFitMode = newFitMode;
    });
  }

  double _getAspectRatio() {
    final firstStream = widget.watchInfo.videoStreams?.firstOrNull;
    if (firstStream != null &&
        firstStream.width != null &&
        firstStream.height != null) {
      return firstStream.width! / firstStream.height!;
    }
    return 16 / 9;
  }

  BoxFit _getBoxFit(String fitMode) {
    switch (fitMode) {
      case 'cover':
        return BoxFit.cover;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'contain':
      default:
        return BoxFit.contain;
    }
  }

  void _updateVideoHistory() {
    final currentPosition = _player.state.position;

    _watchBloc
        .add(WatchEvent.updatePlayBack(playBack: currentPosition.inSeconds));

    if (currentPosition.inSeconds > 0 && widget.videoId.isNotEmpty) {
      final videoInfo = LocalStoreVideoInfo(
        id: widget.videoId,
        title: widget.watchInfo.title,
        views: widget.watchInfo.viewCount,
        thumbnail: widget.watchInfo.thumbnailUrl,
        uploadedDate: widget.watchInfo.textualUploadDate ?? '',
        uploaderAvatar: widget.watchInfo.uploaderAvatarUrl,
        uploaderName: widget.watchInfo.uploaderName,
        uploaderId: _extractChannelId(widget.watchInfo.uploaderUrl),
        uploaderSubscriberCount:
            widget.watchInfo.uploaderSubscriberCount?.toString() ?? '0',
        duration: widget.watchInfo.duration,
        uploaderVerified: widget.watchInfo.uploaderVerified,
        isHistory: true,
        isLive: widget.watchInfo.isLive,
        // isSaved will be preserved by updatePlaybackPosition event
        isSaved: false,
        playbackPosition: currentPosition.inSeconds,
      );

      // Use updatePlaybackPosition instead of addVideoInfo to preserve isSaved state
      _savedBloc.add(SavedEvent.updatePlaybackPosition(videoInfo: videoInfo));
    }
  }

  String? _extractChannelId(String? uploaderUrl) {
    if (uploaderUrl == null) return null;
    final uri = Uri.tryParse(uploaderUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final channelIndex = uri.pathSegments.indexOf('channel');
      if (channelIndex != -1 && channelIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[channelIndex + 1];
      }
    }
    return null;
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showError(String message) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showToast(message);
      });
    }
  }
}

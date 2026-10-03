import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/watch/widgets/newpipe/exoplayer_video_player.dart';
import 'package:fluxtube/presentation/watch/widgets/newpipe/media_kit_video_player.dart';
import 'package:fluxtube/widgets/widgets.dart';

import 'widgets/newpipe/comment_widgets.dart';
import 'widgets/newpipe/description_section.dart';
import 'widgets/newpipe/like_section.dart';
import 'widgets/newpipe/related_video_section.dart';
import 'widgets/newpipe/subscribe_section.dart';

class NewPipeScreenWatch extends StatefulWidget {
  const NewPipeScreenWatch({
    super.key,
    required this.id,
    required this.channelId,
  });

  final String id;
  final String channelId;

  @override
  State<NewPipeScreenWatch> createState() => _NewPipeScreenWatchState();
}

class _NewPipeScreenWatchState extends State<NewPipeScreenWatch>
    with WidgetsBindingObserver {
  // Track if player should be shown - once shown, keep it shown until video ID changes
  // This prevents the player from being disposed during BlocBuilder rebuilds
  bool _showPlayer = false;
  // Track the video ID for which the player is shown
  String? _playerVideoId;
  // Survives a layout change. Replaced only when the video id changes.
  GlobalKey _playerKey = GlobalKey();
  GlobalKey _commentKey = GlobalKey();
  // A new video opens at the top. The dismiss widget is keyed by video id,
  // which recreates this scroll view, so a saved offset must not come back.
  final ScrollController _watchScroll =
      ScrollController(keepScrollOffset: false);
  bool _slidePopped = false;
  // Captured while the element is active. dispose() cannot look up ancestors.
  WatchBloc? _watchBloc;
  void _enterAppPipAndPop() {
    GlobalPlayerController().enterPipMode();
    BlocProvider.of<WatchBloc>(context).add(WatchEvent.togglePip(value: true));
    Navigator.pop(context);
  }

  bool _popFromSlide() {
    if (_slidePopped || !mounted) return _slidePopped;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return false;
    _slidePopped = true;
    navigator.pop();
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer initialization to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeVideo();
      }
    });
  }

  void _evictRelatedThumbnails() {
    final related = _watchBloc?.state.newPipeWatchResp.relatedStreams;
    if (related == null) return;
    final cache = PaintingBinding.instance.imageCache;
    for (final stream in related) {
      _evictSmallThumbnail(cache, stream.thumbnailUrl);
      _evictSmallThumbnail(cache, stream.uploaderAvatarUrl);
    }
  }

  void _evictSmallThumbnail(ImageCache cache, String? url) {
    if (url == null || url.isEmpty) return;
    // ThumbnailImage.small stores ResizeImage(provider, width: 320), not a
    // provider whose maxWidth is 320.
    cache.evict(ResizeImage(CachedNetworkImageProvider(url), width: 320));
  }

  @override
  void dispose() {
    _evictRelatedThumbnails();
    _watchScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Disable PIP when watch screen becomes visible (resumed)
    if (state == AppLifecycleState.resumed) {
      // Check if this route is currently visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
          if (isCurrent && !GlobalPlayerController().isSystemPipMode) {
            BlocProvider.of<WatchBloc>(context)
                .add(WatchEvent.togglePip(value: false));
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant NewPipeScreenWatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video ID changed (e.g., user clicked a related video), reinitialize
    if (oldWidget.id != widget.id) {
      _evictRelatedThumbnails();
      debugPrint(
          '[NewPipeScreenWatch] Video ID changed from ${oldWidget.id} to ${widget.id}');
      _playerKey = GlobalKey();
      _commentKey = GlobalKey();
      _slidePopped = false;
      // Reset player visibility for new video
      setState(() {
        _showPlayer = false;
        _playerVideoId = null;
      });
      _initializeVideo();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchBloc = context.read<WatchBloc>();
    // Handle when this watch screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (isCurrent) {
          final globalPlayer = GlobalPlayerController();
          final currentPlayingId = globalPlayer.currentVideoId;

          // If a DIFFERENT video is currently playing, this is an old watch screen
          // that the user navigated back to. Auto-pop it to go to the actual current video.
          if (currentPlayingId != null &&
              currentPlayingId != widget.id &&
              globalPlayer.isPlaying) {
            debugPrint(
                '[NewPipeScreenWatch] Old watch screen detected (this: ${widget.id}, playing: $currentPlayingId). Auto-popping.');
            Navigator.of(context).pop();
            return;
          }

          // Disable PIP when returning to watch screen from another route
          final watchBloc = BlocProvider.of<WatchBloc>(context);
          if (watchBloc.state.isPipEnabled && !globalPlayer.isSystemPipMode) {
            watchBloc.add(WatchEvent.togglePip(value: false));
          }
        }
      }
    });
  }

  void _initializeVideo() async {
    final watchBloc = BlocProvider.of<WatchBloc>(context);
    final savedBloc = BlocProvider.of<SavedBloc>(context);
    final subscribeBloc = BlocProvider.of<SubscribeBloc>(context);
    final settingsBloc = BlocProvider.of<SettingsBloc>(context);
    final settingsState = settingsBloc.state;
    final currentProfile = settingsState.currentProfile;

    final globalPlayer = GlobalPlayerController();
    final currentPlayingId = globalPlayer.currentVideoId;

    // If a different video is playing, stop it first
    if (currentPlayingId != null && currentPlayingId != widget.id) {
      debugPrint(
          '[NewPipeScreenWatch] Stopping previous video: $currentPlayingId (starting: ${widget.id})');
      await globalPlayer.stopAndClear();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Validate before starting any video
    await globalPlayer.validateBeforePlay(widget.id);

    // Check if returning from PiP with same video already loaded
    final isReturningFromPip = globalPlayer.hasVideoLoaded(widget.id) &&
        watchBloc.state.newPipeWatchResp.id == widget.id;

    if (!globalPlayer.isSystemPipMode) {
      watchBloc.add(WatchEvent.togglePip(value: false));
    }

    // Only fetch data if not returning from PiP with data already loaded
    if (!isReturningFromPip) {
      // Use fast loading with parallel SponsorBlock fetch
      watchBloc.add(WatchEvent.getNewPipeWatchInfoFast(
        id: widget.id,
        sponsorBlockCategories: settingsState.isSponsorBlockEnabled
            ? settingsState.sponsorBlockCategories
            : [],
      ));
    }

    // Saved state and subscription check can run in parallel
    // Only fetch all videos list if not returning from PiP
    if (!isReturningFromPip) {
      savedBloc
          .add(SavedEvent.getAllVideoInfoList(profileName: currentProfile));
    }

    // Only check video info if we don't already have it for this video
    // This prevents flickering when returning from PiP
    if (savedBloc.state.videoInfo?.id != widget.id) {
      savedBloc.add(SavedEvent.checkVideoInfo(
          id: widget.id, profileName: currentProfile));
    }

    subscribeBloc.add(SubscribeEvent.checkSubscribeInfo(
        id: widget.channelId, profileName: currentProfile));
  }

  @override
  Widget build(BuildContext context) {
    final locals = S.of(context);
    final double height = MediaQuery.of(context).size.height;

    return BlocListener<WatchBloc, WatchState>(
      listenWhen: (previous, current) =>
          previous.fetchNewPipeWatchInfoStatus !=
              current.fetchNewPipeWatchInfoStatus &&
          current.fetchNewPipeWatchInfoStatus == ApiStatus.loaded,
      listener: (context, state) {
        // Set selectedVideoBasicDetails when video info is loaded
        // This ensures PIP works when navigating from external links
        final watchInfo = state.newPipeWatchResp;
        if (watchInfo.id != null && watchInfo.id!.isNotEmpty) {
          final currentInfo = VideoBasicInfo(
            id: watchInfo.id!,
            title: watchInfo.title,
            thumbnailUrl: watchInfo.thumbnailUrl,
            channelName: watchInfo.uploaderName,
            channelId: watchInfo.uploaderUrl?.split('/').last,
            uploaderVerified: watchInfo.uploaderVerified,
          );
          BlocProvider.of<WatchBloc>(context).add(
            WatchEvent.setSelectedVideoBasicDetails(details: currentInfo),
          );
          PlaybackQueue().seedFromRelated(
            current: currentInfo,
            related: (watchInfo.relatedStreams ?? []).map((related) {
              final id = _videoIdFromUrl(related.url);
              return VideoBasicInfo(
                id: id,
                title: related.name,
                thumbnailUrl: related.thumbnailUrl,
                channelName: related.uploaderName,
                channelId: _channelIdFromUrl(related.uploaderUrl),
                channelThumbnailUrl: related.uploaderAvatarUrl,
                uploaderVerified: related.uploaderVerified,
              );
            }),
          );
        }
      },
      child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (previous, current) =>
            previous.defaultQuality != current.defaultQuality ||
            previous.isHlsPlayer != current.isHlsPlayer ||
            previous.isPipDisabled != current.isPipDisabled ||
            previous.isHideRelated != current.isHideRelated ||
            previous.videoFitMode != current.videoFitMode ||
            previous.skipInterval != current.skipInterval ||
            previous.subtitleSize != current.subtitleSize ||
            previous.isAutoPipEnabled != current.isAutoPipEnabled,
        builder: (context, settingsState) {
          return BlocBuilder<WatchBloc, WatchState>(
            buildWhen: (previous, current) =>
                previous.fetchNewPipeWatchInfoStatus !=
                    current.fetchNewPipeWatchInfoStatus ||
                previous.newPipeWatchResp != current.newPipeWatchResp ||
                previous.isDescriptionTapped != current.isDescriptionTapped ||
                previous.isTapComments != current.isTapComments ||
                previous.fetchNewPipeCommentsStatus !=
                    current.fetchNewPipeCommentsStatus ||
                previous.newPipeComments != current.newPipeComments ||
                previous.fetchMoreNewPipeCommentsStatus !=
                    current.fetchMoreNewPipeCommentsStatus ||
                previous.isMoreNewPipeCommentsFetchCompleted !=
                    current.isMoreNewPipeCommentsFetchCompleted ||
                previous.sponsorSegments != current.sponsorSegments,
            builder: (context, state) {
              return BlocBuilder<SavedBloc, SavedState>(
                buildWhen: (previous, current) =>
                    previous.videoInfo?.id != current.videoInfo?.id ||
                    previous.videoInfo?.isSaved != current.videoInfo?.isSaved ||
                    previous.videoInfo?.playbackPosition !=
                        current.videoInfo?.playbackPosition,
                builder: (context, savedState) {
                  final watchInfo = state.newPipeWatchResp;

                  if (state.fetchNewPipeWatchInfoStatus == ApiStatus.error) {
                    return Scaffold(
                      appBar: AppBar(
                        title: Text(locals.retry),
                      ),
                      body: SafeArea(
                        child: SingleChildScrollView(
                          child: InstanceAutoCheckWidget(
                            videoId: widget.id,
                            lottie: 'assets/cat-404.zip',
                            errorMessage: state.newPipeErrorMessage,
                            onRetry: () => BlocProvider.of<WatchBloc>(context)
                                .add(WatchEvent.getNewPipeWatchInfo(
                                    id: widget.id)),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return _SlideDownDismiss(
                      key: ValueKey(widget.id),
                      onDismissed: _popFromSlide,
                      child: PopScope(
                        canPop: true,
                        onPopInvokedWithResult: (didPop, _) {
                          if (didPop && !settingsState.isPipDisabled) {
                            GlobalPlayerController().enterPipMode();
                            BlocProvider.of<WatchBloc>(context)
                                .add(WatchEvent.togglePip(value: true));
                          }
                        },
                        child: Scaffold(
                          body: SafeArea(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final split = constraints.maxWidth.isFinite &&
                                    WindowLayout.useWatchSplit(
                                        constraints.maxWidth);
                                final player = _buildPlayer(
                                  state,
                                  savedState,
                                  settingsState,
                                );
                                final details = _buildDetails(
                                  state: state,
                                  settingsState: settingsState,
                                  locals: locals,
                                  height: height,
                                  watchInfo: watchInfo,
                                  wide: split,
                                );
                                final scrollBehavior =
                                    ScrollConfiguration.of(context);
                                final page = ScrollConfiguration(
                                  behavior: scrollBehavior.copyWith(
                                    dragDevices: {
                                      ...scrollBehavior.dragDevices,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                                  child:
                                      NotificationListener<ScrollNotification>(
                                    onNotification: (notification) {
                                      _SlideDownDismiss.maybeOf(context)
                                          ?.handle(notification);
                                      return false;
                                    },
                                    child: SingleChildScrollView(
                                      controller: _watchScroll,
                                      physics: _WatchSlidePhysics(
                                        blockUpwardScroll: () {
                                          if (!context.mounted) return false;
                                          return _SlideDownDismiss.maybeOf(
                                                      context)
                                                  ?.holdingScroll ??
                                              false;
                                        },
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          player,
                                          details,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                if (!split) return page;
                                final showSide = state.isTapComments ||
                                    !settingsState.isHideRelated;
                                if (!showSide) return page;
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 7, child: page),
                                    Expanded(
                                      flex: 3,
                                      child: _buildSide(
                                        state: state,
                                        locals: locals,
                                        height: height,
                                        watchInfo: watchInfo,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlayer(
    WatchState state,
    SavedState savedState,
    SettingsState settingsState,
  ) {
    // Show player if:
    // 1. Watch info is loaded for this video, OR
    // 2. Returning from PiP (player has this video with data)
    // CRITICAL: Once player is shown, keep it shown to prevent
    // disposal during BlocBuilder rebuilds
    return Builder(
      builder: (context) {
        final useNativePlayer =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

        // Check if we should show the player
        final shouldShowPlayer = _showPlayer && _playerVideoId == widget.id;
        final hasLoadedWatchInfo =
            state.fetchNewPipeWatchInfoStatus == ApiStatus.loaded &&
                state.newPipeWatchResp.id == widget.id;
        final canShowPlayer = hasLoadedWatchInfo ||
            (!useNativePlayer &&
                GlobalPlayerController().hasVideoLoaded(widget.id));

        // Once we can show the player, set _showPlayer to true
        // This ensures the player stays in the tree during rebuilds
        if (canShowPlayer && !shouldShowPlayer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_showPlayer) {
              setState(() {
                _showPlayer = true;
                _playerVideoId = widget.id;
              });
            }
          });
        }

        // Show player if either condition is true
        return (shouldShowPlayer || canShowPlayer)
            ? useNativePlayer
                ? NewPipeExoPlayer(
                    key: ValueKey('exo_player_${widget.id}'),
                    videoId: widget.id,
                    watchInfo: state.newPipeWatchResp,
                    playbackPosition: savedState.videoInfo?.id == widget.id
                        ? (savedState.videoInfo?.playbackPosition ?? 0)
                        : 0,
                    defaultQuality: settingsState.defaultQuality,
                    videoFitMode: settingsState.videoFitMode,
                    skipInterval: settingsState.skipInterval,
                    sponsorSegments: settingsState.isSponsorBlockEnabled
                        ? state.sponsorSegments
                        : const [],
                    preferAdaptivePlayback: settingsState.isHlsPlayer,
                    isAutoPipEnabled: settingsState.isAutoPipEnabled,
                  )
                : NewPipeMediaKitPlayer(
                    // Replaced only when the video id changes, so a
                    // resize keeps this player's state.
                    key: _playerKey,
                    videoId: widget.id,
                    watchInfo: state.newPipeWatchResp,
                    // Only use playback position if it's for the current video
                    // This prevents using the previous video's position when switching videos
                    playbackPosition: savedState.videoInfo?.id == widget.id
                        ? (savedState.videoInfo?.playbackPosition ?? 0)
                        : 0,
                    defaultQuality: settingsState.defaultQuality,
                    videoFitMode: settingsState.videoFitMode,
                    skipInterval: settingsState.skipInterval,
                    subtitleSize: settingsState.subtitleSize,
                    sponsorSegments: settingsState.isSponsorBlockEnabled
                        ? state.sponsorSegments
                        : const [],
                    isAutoPipEnabled: settingsState.isAutoPipEnabled,
                    preferAdaptivePlayback: settingsState.isHlsPlayer,
                  )
            : Container(
                height: 200,
                color: kBlackColor,
                child: Center(
                  child: cIndicator(context),
                ),
              );
      },
    );
  }

  Widget _buildDetails({
    required WatchState state,
    required SettingsState settingsState,
    required S locals,
    required double height,
    required NewPipeWatchResp watchInfo,
    required bool wide,
  }) {
    final loading = state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
        state.fetchNewPipeWatchInfoStatus == ApiStatus.loading;
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          (state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
                  state.fetchNewPipeWatchInfoStatus == ApiStatus.loading)
              ? CaptionRowWidget(
                  caption: state.selectedVideoBasicDetails?.title ??
                      locals.noVideoTitle,
                  icon: state.isDescriptionTapped
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                )
              : GestureDetector(
                  onTap: () => BlocProvider.of<WatchBloc>(context)
                      .add(WatchEvent.tapDescription()),
                  child: CaptionRowWidget(
                    caption: watchInfo.title ?? locals.noVideoTitle,
                    icon: state.isDescriptionTapped
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                  ),
                ),
          kHeightBox5,
          (state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
                  state.fetchNewPipeWatchInfoStatus == ApiStatus.loading)
              ? const SizedBox()
              : ViewRowWidget(
                  views: watchInfo.viewCount,
                  uploadedDate: watchInfo.textualUploadDate ?? '',
                ),
          kHeightBox10,
          (state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
                  state.fetchNewPipeWatchInfoStatus == ApiStatus.loading)
              ? const ShimmerLikeWidget()
              : NewPipeLikeSection(
                  id: widget.id,
                  state: state,
                  watchInfo: watchInfo,
                  pipClicked: () {
                    _enterAppPipAndPop();
                  },
                ),
          kHeightBox10,
          const Divider(),
          (state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
                  state.fetchNewPipeWatchInfoStatus == ApiStatus.loading)
              ? const ShimmerSubscribeWidget()
              : NewPipeChannelInfoSection(
                  state: state,
                  watchInfo: watchInfo,
                  locals: locals,
                  keepVisible: wide),
          if (wide || !state.isTapComments) const Divider(),
          kHeightBox10,
          if (wide)
            state.isDescriptionTapped
                ? NewPipeDescriptionSection(
                    height: height,
                    watchInfo: watchInfo,
                    locals: locals,
                    limitHeight: false,
                  )
                : const SizedBox()
          else
            _buildNarrowStream(
              state: state,
              settingsState: settingsState,
              locals: locals,
              height: height,
              watchInfo: watchInfo,
              loading: loading,
            ),
        ],
      ),
    );
  }

  Widget _buildNarrowStream({
    required WatchState state,
    required SettingsState settingsState,
    required S locals,
    required double height,
    required NewPipeWatchResp watchInfo,
    required bool loading,
  }) {
    if (state.isDescriptionTapped) {
      return NewPipeDescriptionSection(
        height: height,
        watchInfo: watchInfo,
        locals: locals,
      );
    }
    if (!state.isTapComments) {
      if (settingsState.isHideRelated) return const SizedBox();
      if (loading) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return const ShimmerRelatedVideoWidget();
          },
        );
      }
      return NewPipeRelatedVideoSection(
        locals: locals,
        watchInfo: watchInfo,
      );
    }
    return NewPipeCommentSection(
      key: _commentKey,
      videoId: widget.id,
      state: state,
      height: height,
      locals: locals,
    );
  }

  Widget _buildSide({
    required WatchState state,
    required S locals,
    required double height,
    required NewPipeWatchResp watchInfo,
  }) {
    final loading = state.fetchNewPipeWatchInfoStatus == ApiStatus.initial ||
        state.fetchNewPipeWatchInfoStatus == ApiStatus.loading;
    if (state.isTapComments) {
      return NewPipeCommentSection(
        key: _commentKey,
        fillColumn: true,
        videoId: widget.id,
        state: state,
        height: height,
        locals: locals,
      );
    }
    if (loading) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return const ShimmerRelatedVideoWidget();
        },
      );
    }
    return NewPipeRelatedVideoSection(
      fillColumn: true,
      locals: locals,
      watchInfo: watchInfo,
    );
  }

  String _videoIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['v'] ?? url.split('/').last.split('?').first;
  }

  String? _channelIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final parts = url.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }
}

class _SlideDownDismiss extends StatefulWidget {
  const _SlideDownDismiss({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  final Widget child;
  final bool Function() onDismissed;

  static _SlideDownDismissState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_SlideDownDismissState>();
  }

  @override
  State<_SlideDownDismiss> createState() => _SlideDownDismissState();
}

class _SlideDownDismissState extends State<_SlideDownDismiss>
    with SingleTickerProviderStateMixin {
  static const double _dismissFraction = 0.15;

  late final AnimationController _offset;
  bool _tracking = false;
  bool _settling = false;

  /// True while a finger or mouse button is pulling the page down, so an
  /// upward drag pulls the page back instead of scrolling the column.
  bool get holdingScroll => _tracking && _offset.value > 0;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void handle(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || _settling) return;
    if (notification is ScrollEndNotification) {
      _settle();
      return;
    }
    if (notification is! OverscrollNotification) return;
    // A wheel tick has no drag details. It must scroll, not slide.
    if (notification.dragDetails == null) return;

    final overscroll = notification.overscroll;
    if (overscroll < 0) {
      if (notification.metrics.pixels > 0) return;
      _offset.stop();
      _tracking = true;
      _offset.value -= overscroll;
      return;
    }
    if (overscroll > 0 && holdingScroll) {
      _offset.stop();
      _offset.value = math.max(0.0, _offset.value - overscroll);
      if (_offset.value == 0) _tracking = false;
    }
  }

  void _settle({bool cancelled = false}) {
    if (_settling) return;
    if (!_tracking && _offset.value == 0) return;
    _settling = true;
    _tracking = false;
    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    final dismiss =
        !cancelled && height > 0 && _offset.value / height > _dismissFraction;
    if (dismiss && widget.onDismissed()) return;
    _offset
        .animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    )
        .whenComplete(() {
      if (!mounted) return;
      _settling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (_) => _settle(),
      onPointerCancel: (_) => _settle(cancelled: true),
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _offset.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// While the page is sliding down, an upward drag is overscroll instead of
/// column movement, so the same drag pulls the page back.
class _WatchSlidePhysics extends ScrollPhysics {
  const _WatchSlidePhysics({required this.blockUpwardScroll, super.parent});

  final bool Function() blockUpwardScroll;

  @override
  _WatchSlidePhysics applyTo(ScrollPhysics? ancestor) {
    return _WatchSlidePhysics(
      blockUpwardScroll: blockUpwardScroll,
      parent: buildParent(ancestor),
    );
  }

  /// A maximized window can fit the column, and the default physics then
  /// refuse the drag. The downward overscroll is what starts the slide.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (blockUpwardScroll() && value > position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

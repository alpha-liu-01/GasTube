import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:fluxtube/domain/search/models/newpipe/newpipe_search_resp.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/home_scroll.dart';
import 'package:fluxtube/presentation/search/widgets/newpipe/home_video_info_card_widget.dart';
import 'package:fluxtube/presentation/shorts/screen_shorts.dart';
import 'package:fluxtube/widgets/card_row.dart';
import 'package:fluxtube/widgets/shimmers/shimmer_home_video_card.dart';
import 'package:go_router/go_router.dart';

/// Personalized home feed with mixed content (videos and shorts)
class PersonalizedFeedSection extends StatefulWidget {
  const PersonalizedFeedSection({
    super.key,
    required this.trendingState,
    required this.locals,
    required this.settingsState,
  });

  final TrendingState trendingState;
  final S locals;
  final SettingsState settingsState;

  @override
  State<PersonalizedFeedSection> createState() =>
      _PersonalizedFeedSectionState();
}

class _PersonalizedFeedSectionState extends State<PersonalizedFeedSection>
    with HomeListScroll {
  @override
  void onHomeScroll() {
    if (!homeScrollController.hasClients) return;
    if (homeScrollController.position.pixels >=
        homeScrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled (earlier trigger)
      if (!widget.trendingState.isLoadingMorePersonalizedFeed &&
          widget.trendingState.hasMorePersonalizedContent) {
        BlocProvider.of<TrendingBloc>(context).add(
          TrendingEvent.loadMorePersonalizedFeed(
            profileName: widget.settingsState.currentProfile,
            serviceType: widget.settingsState.ytService,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show shimmer while loading
    if (widget.trendingState.fetchPersonalizedFeedStatus == ApiStatus.loading) {
      return const ShimmerHomeVideoGrid(itemCount: 3);
    }

    final items =
        widget.trendingState.personalizedFeedResult.cast<NewPipeSearchItem>();

    // Only show empty state if loaded and actually empty
    if (items.isEmpty &&
        widget.trendingState.fetchPersonalizedFeedStatus == ApiStatus.loaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No videos available',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    // Show shimmer if still in initial state
    if (items.isEmpty) {
      return const ShimmerHomeVideoGrid(itemCount: 3);
    }

    // Separate shorts and videos for mixed layout
    final shorts = <NewPipeSearchItem>[];
    final videos = <NewPipeSearchItem>[];

    for (final item in items) {
      if (item.isShort == true) {
        shorts.add(item);
      } else {
        videos.add(item);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        revealHomeHeader();
        final columns = constraints.maxWidth.isFinite
            ? WindowLayout.cardColumns(constraints.maxWidth)
            : 1;
        if (columns == 1) {
          return _buildVideoList(videos, shorts);
        }
        return _buildVideoGrid(videos, shorts, columns);
      },
    );
  }

  Widget _buildVideoList(
    List<NewPipeSearchItem> videos,
    List<NewPipeSearchItem> shorts,
  ) {
    return ListView.separated(
      controller: homeScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      separatorBuilder: (context, index) {
        final shortsToShow = _shortsAfter(index, shorts);
        if (shortsToShow != null) {
          return Column(
            children: [
              kHeightBox10,
              _ShortsSection(
                shorts: shortsToShow,
                locals: widget.locals,
              ),
              kHeightBox10,
            ],
          );
        }
        return kHeightBox10;
      },
      itemCount: videos.length +
          (widget.trendingState.isLoadingMorePersonalizedFeed ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= videos.length) {
          return const ShimmerHomeVideoInfoCard();
        }
        return _buildVideoCard(videos[index], aspectRatioThumbnail: false);
      },
    );
  }

  Widget _buildVideoGrid(
    List<NewPipeSearchItem> videos,
    List<NewPipeSearchItem> shorts,
    int columns,
  ) {
    final slivers = <Widget>[];
    final row = <int>[];

    void flushRow() {
      if (row.isEmpty) return;
      final indexes = List<int>.from(row);
      row.clear();
      slivers.add(
        SliverToBoxAdapter(
          child: CardRow(
            columns: columns,
            children: [
              for (final index in indexes)
                _buildVideoCard(
                  videos[index],
                  aspectRatioThumbnail: true,
                ),
            ],
          ),
        ),
      );
    }

    for (var index = 0; index < videos.length; index++) {
      if (!_canShowVideo(videos[index])) continue;
      row.add(index);
      if (row.length == columns) flushRow();
      final shortsToShow = _shortsAfter(index, shorts);
      if (shortsToShow != null) {
        flushRow();
        slivers.add(
          SliverToBoxAdapter(
            child: Column(
              children: [
                kHeightBox10,
                _ShortsSection(
                  shorts: shortsToShow,
                  locals: widget.locals,
                ),
                kHeightBox10,
              ],
            ),
          ),
        );
      }
    }
    flushRow();

    if (widget.trendingState.isLoadingMorePersonalizedFeed) {
      slivers.add(
        SliverToBoxAdapter(
          child: ShimmerHomeVideoRow(columns: columns),
        ),
      );
    }

    return CustomScrollView(
      controller: homeScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 10)),
        ...slivers,
        const SliverPadding(padding: EdgeInsets.only(bottom: 10)),
      ],
    );
  }

  /// Shorts strip that the one-column separator inserts after [index].
  List<NewPipeSearchItem>? _shortsAfter(
    int index,
    List<NewPipeSearchItem> shorts,
  ) {
    if (shorts.isEmpty ||
        index <= 0 ||
        index % 6 != 0 ||
        index / 6 > (shorts.length / 5).ceil()) {
      return null;
    }
    final start = ((index ~/ 6) - 1) * 5;
    final end = (start + 5).clamp(0, shorts.length);
    if (start >= end) return null;
    final slice = shorts.sublist(start, end);
    if (slice.isEmpty) return null;
    return slice;
  }

  bool _canShowVideo(NewPipeSearchItem video) {
    final videoId =
        video.videoId ?? video.url?.split('v=').last.split('&').first ?? '';
    final channelId = video.uploaderUrl?.split('/').last ?? '';
    return videoId.isNotEmpty && channelId.isNotEmpty;
  }

  Widget _buildVideoCard(
    NewPipeSearchItem video, {
    required bool aspectRatioThumbnail,
  }) {
    final videoId =
        video.videoId ?? video.url?.split('v=').last.split('&').first ?? '';
    final channelId = video.uploaderUrl?.split('/').last ?? '';

    if (videoId.isEmpty || channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<SubscribeBloc, SubscribeState>(
      builder: (context, subscribeState) {
        final isSubscribed = subscribeState.subscribedChannels
            .any((channel) => channel.id == channelId);

        return GestureDetector(
          key: ValueKey('personalized_$videoId'),
          onTap: () {
            context.read<WatchBloc>().add(
                  WatchEvent.setSelectedVideoBasicDetails(
                    details: VideoBasicInfo(
                      id: videoId,
                      title: video.name,
                      thumbnailUrl: video.thumbnailUrl,
                      channelName: video.uploaderName,
                      channelThumbnailUrl: video.uploaderAvatarUrl,
                      channelId: channelId,
                      uploaderVerified: video.uploaderVerified ?? false,
                    ),
                  ),
                );

            context
                .read<SavedBloc>()
                .add(SavedEvent.trackVideoWatch(videoId: videoId));

            context.goNamed('watch', pathParameters: {
              'videoId': videoId,
              'channelId': channelId,
            });
          },
          child: NewPipeSearchVideoInfoCardWidget(
            channelId: channelId,
            cardInfo: video,
            isSubscribed: isSubscribed,
            subscribeRowVisible: true,
            aspectRatioThumbnail: aspectRatioThumbnail,
            onSubscribeTap: () {
              if (isSubscribed) {
                context.read<SubscribeBloc>().add(
                      SubscribeEvent.deleteSubscribeInfo(id: channelId),
                    );
              } else {
                context.read<SubscribeBloc>().add(
                      SubscribeEvent.addSubscribe(
                        channelInfo: Subscribe(
                          id: channelId,
                          channelName: video.uploaderName ?? '',
                          avatarUrl: video.uploaderAvatarUrl,
                          isVerified: video.uploaderVerified,
                          profileName: widget.settingsState.currentProfile,
                        ),
                        profileName: widget.settingsState.currentProfile,
                      ),
                    );
              }
            },
          ),
        );
      },
    );
  }
}

/// Horizontal shorts section
class _ShortsSection extends StatelessWidget {
  const _ShortsSection({
    required this.shorts,
    required this.locals,
  });

  final List<NewPipeSearchItem> shorts;
  final S locals;

  @override
  Widget build(BuildContext context) {
    if (shorts.isEmpty) return const SizedBox.shrink();

    // Convert NewPipeSearchItem to ShortItem
    final shortItems = shorts.map((s) {
      final videoId =
          s.videoId ?? s.url?.split('v=').last.split('&').first ?? '';
      return ShortItem(
        id: videoId,
        title: s.name,
        thumbnailUrl: s.thumbnailUrl,
        uploaderName: s.uploaderName,
        uploaderAvatar: s.uploaderAvatarUrl,
        uploaderId: s.uploaderUrl?.split('/').last,
        viewCount: s.viewCount,
        duration: s.duration,
        uploaderVerified: s.uploaderVerified,
      );
    }).toList();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.play_rectangle_fill,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                locals.shorts,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Horizontal shorts list
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: shortItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final short = shortItems[index];
              return _ShortCard(
                short: short,
                onTap: () => _openShorts(context, shortItems, index),
              );
            },
          ),
        ),
        AppSpacing.height12,
      ],
    );
  }

  void _openShorts(
      BuildContext context, List<ShortItem> shortItems, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScreenShorts(
          shorts: shortItems,
          initialIndex: index,
        ),
      ),
    );
  }
}

/// Individual short card matching search result design
class _ShortCard extends StatelessWidget {
  const _ShortCard({
    required this.short,
    required this.onTap,
  });

  final ShortItem short;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              if (short.thumbnailUrl != null)
                Image.network(
                  short.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    child: Icon(
                      Icons.video_library,
                      size: 40,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                  ),
                )
              else
                Container(
                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                  child: Icon(
                    Icons.video_library,
                    size: 40,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                ),

              // Gradient overlay for text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // View count
              if (short.viewCount != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    _formatViews(short.viewCount!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Shorts icon indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_rectangle_fill,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '$views views';
  }
}

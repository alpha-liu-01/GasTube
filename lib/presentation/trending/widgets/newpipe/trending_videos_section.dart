import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/trending/models/newpipe/newpipe_trending_resp.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/home_scroll.dart';
import 'package:fluxtube/presentation/trending/widgets/newpipe/home_video_info_card_widget.dart';
import 'package:fluxtube/widgets/card_row.dart';
import 'package:go_router/go_router.dart';

class NewPipeTrendingVideosSection extends StatefulWidget {
  const NewPipeTrendingVideosSection({
    super.key,
    required this.locals,
    required this.state,
  });

  final S locals;
  final TrendingState state;

  @override
  State<NewPipeTrendingVideosSection> createState() =>
      _NewPipeTrendingVideosSectionState();
}

class _NewPipeTrendingVideosSectionState
    extends State<NewPipeTrendingVideosSection> with HomeListScroll {
  @override
  void onHomeScroll() {
    if (_isBottom) {
      context.read<TrendingBloc>().add(
            const TrendingEvent.loadMoreNewPipeTrending(),
          );
    }
  }

  bool get _isBottom {
    if (!homeScrollController.hasClients) return false;
    final maxScroll = homeScrollController.position.maxScrollExtent;
    final currentScroll = homeScrollController.offset;
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    revealHomeHeader();
    final displayCount = widget.state.newPipeTrendingDisplayCount;
    final totalCount = widget.state.newPipeTrendingResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.state.isLoadingMoreNewPipeTrending;

    return BlocBuilder<SubscribeBloc, SubscribeState>(
      buildWhen: (previous, current) =>
          previous.subscribedChannels != current.subscribedChannels,
      builder: (context, subscribeState) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth.isFinite
                ? WindowLayout.cardColumns(constraints.maxWidth)
                : 1;
            if (columns == 1) {
              return _buildVideoList(
                subscribeState,
                itemCount,
                hasMore,
                isLoading,
              );
            }
            return _buildVideoGrid(
              subscribeState,
              itemCount,
              hasMore,
              isLoading,
              columns,
            );
          },
        );
      },
    );
  }

  Widget _buildVideoList(
    SubscribeState subscribeState,
    int itemCount,
    bool hasMore,
    bool isLoading,
  ) {
    return ListView.separated(
      controller: homeScrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      separatorBuilder: (context, index) => kHeightBox10,
      itemBuilder: (context, index) {
        if (index >= itemCount) {
          return _buildLoadingIndicator(hasMore, isLoading);
        }
        return _buildVideoCard(
          widget.state.newPipeTrendingResult[index],
          subscribeState,
          aspectRatioThumbnail: false,
        );
      },
      itemCount: hasMore ? itemCount + 1 : itemCount,
    );
  }

  Widget _buildVideoGrid(
    SubscribeState subscribeState,
    int itemCount,
    bool hasMore,
    bool isLoading,
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
                  widget.state.newPipeTrendingResult[index],
                  subscribeState,
                  aspectRatioThumbnail: true,
                ),
            ],
          ),
        ),
      );
    }

    for (var index = 0; index < itemCount; index++) {
      if (!_canShowVideo(widget.state.newPipeTrendingResult[index])) continue;
      row.add(index);
      if (row.length == columns) flushRow();
    }
    flushRow();

    if (hasMore) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildLoadingIndicator(hasMore, isLoading),
        ),
      );
    }

    return CustomScrollView(
      controller: homeScrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      slivers: slivers,
    );
  }

  bool _canShowVideo(NewPipeTrendingResp trending) {
    final videoId = trending.videoId;
    if (videoId == null || videoId.isEmpty) return false;
    final channelId = trending.uploaderUrl?.split('/').last ?? '';
    return channelId.isNotEmpty;
  }

  Widget _buildVideoCard(
    NewPipeTrendingResp trending,
    SubscribeState subscribeState, {
    required bool aspectRatioThumbnail,
  }) {
    final String? videoId = trending.videoId;
    if (videoId == null || videoId.isEmpty) {
      return const SizedBox.shrink();
    }

    final String channelId = trending.uploaderUrl?.split("/").last ?? '';
    if (channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isSubscribed = subscribeState.subscribedChannels
        .any((channel) => channel.id == channelId);
    return GestureDetector(
      key: ValueKey('trending_$videoId'),
      onTap: () {
        BlocProvider.of<WatchBloc>(context).add(
            WatchEvent.setSelectedVideoBasicDetails(
                details: VideoBasicInfo(
                    id: videoId,
                    title: trending.name,
                    thumbnailUrl: trending.thumbnailUrl,
                    channelName: trending.uploaderName,
                    channelThumbnailUrl: trending.uploaderAvatarUrl,
                    channelId: channelId,
                    uploaderVerified: trending.uploaderVerified)));
        context.goNamed('watch', pathParameters: {
          'videoId': videoId,
          'channelId': channelId,
        });
      },
      child: NewPipeTrendingVideoInfoCardWidget(
        channelId: channelId,
        cardInfo: trending,
        isSubscribed: isSubscribed,
        aspectRatioThumbnail: aspectRatioThumbnail,
        onSubscribeTap: () {
          if (isSubscribed) {
            BlocProvider.of<SubscribeBloc>(context)
                .add(SubscribeEvent.deleteSubscribeInfo(id: channelId));
          } else {
            BlocProvider.of<SubscribeBloc>(context).add(
                SubscribeEvent.addSubscribe(
                    channelInfo: Subscribe(
                        id: channelId,
                        channelName: trending.uploaderName ??
                            widget.locals.noUploaderName,
                        isVerified: trending.uploaderVerified ?? false)));
          }
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(bool hasMore, bool isLoading) {
    if (!hasMore) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

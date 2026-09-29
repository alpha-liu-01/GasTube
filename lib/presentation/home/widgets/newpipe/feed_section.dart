import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/home_scroll.dart';
import 'package:fluxtube/presentation/trending/widgets/newpipe/home_video_info_card_widget.dart';
import 'package:go_router/go_router.dart';

class NewPipeFeedVideoSection extends StatefulWidget {
  const NewPipeFeedVideoSection({
    super.key,
    required this.locals,
    required this.trendingState,
    required this.subscribeState,
  });

  final S locals;
  final TrendingState trendingState;
  final SubscribeState subscribeState;

  @override
  State<NewPipeFeedVideoSection> createState() =>
      _NewPipeFeedVideoSectionState();
}

class _NewPipeFeedVideoSectionState extends State<NewPipeFeedVideoSection>
    with HomeListScroll {
  @override
  void onHomeScroll() {
    if (_isBottom) {
      context
          .read<TrendingBloc>()
          .add(const TrendingEvent.loadMoreNewPipeFeed());
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
    final displayCount = widget.trendingState.newPipeFeedDisplayCount;
    final totalCount = widget.trendingState.newPipeFeedResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.trendingState.isLoadingMoreNewPipeFeed;

    return ListView.separated(
      controller: homeScrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      separatorBuilder: (context, index) => kHeightBox10,
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index >= itemCount) {
          return _buildLoadingIndicator(hasMore, isLoading);
        }

        final feed = widget.trendingState.newPipeFeedResult[index];
        final String? videoId = feed.videoId;

        if (videoId == null) {
          return const SizedBox.shrink();
        }

        final String channelId = feed.uploaderUrl?.split("/").last ?? '';
        final bool isSubscribed = widget.subscribeState.subscribedChannels
            .where((channel) => channel.id == channelId)
            .isNotEmpty;
        return GestureDetector(
          key: ValueKey('feed_$videoId'),
          onTap: () {
            BlocProvider.of<WatchBloc>(context).add(
                WatchEvent.setSelectedVideoBasicDetails(
                    details: VideoBasicInfo(
                        id: videoId,
                        title: feed.name,
                        thumbnailUrl: feed.thumbnailUrl,
                        channelName: feed.uploaderName,
                        channelThumbnailUrl: feed.uploaderAvatarUrl,
                        channelId: channelId,
                        uploaderVerified: feed.uploaderVerified)));
            context.goNamed('watch', pathParameters: {
              'videoId': videoId,
              'channelId': channelId,
            });
          },
          child: NewPipeTrendingVideoInfoCardWidget(
            channelId: channelId,
            cardInfo: feed,
            isSubscribed: isSubscribed,
            onSubscribeTap: () => _onSubscribeTapped(
                context, isSubscribed, channelId, feed, widget.locals),
          ),
        );
      },
      itemCount: hasMore ? itemCount + 1 : itemCount,
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

void _onSubscribeTapped(BuildContext context, bool isSubscribed, String channelId, dynamic channelDetails, S locals) {
  if (isSubscribed) {
    BlocProvider.of<SubscribeBloc>(context)
        .add(SubscribeEvent.deleteSubscribeInfo(id: channelId));
  } else {
    BlocProvider.of<SubscribeBloc>(context).add(SubscribeEvent.addSubscribe(
        channelInfo: Subscribe(
            id: channelId,
            channelName: channelDetails.uploaderName ?? locals.noUploaderName,
            isVerified: channelDetails.uploaderVerified ?? false)));
  }
}

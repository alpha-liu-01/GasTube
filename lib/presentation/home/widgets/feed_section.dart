import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/home_scroll.dart';
import 'package:fluxtube/widgets/home_video_info_card_widget.dart';
import 'package:go_router/go_router.dart';

class FeedVideoSection extends StatefulWidget {
  const FeedVideoSection({
    super.key,
    required this.locals,
    required this.trendingState,
    required this.subscribeState,
  });

  final S locals;
  final TrendingState trendingState;
  final SubscribeState subscribeState;

  @override
  State<FeedVideoSection> createState() => _FeedVideoSectionState();
}

class _FeedVideoSectionState extends State<FeedVideoSection>
    with HomeListScroll {
  @override
  void onHomeScroll() {
    if (_isBottom) {
      context.read<TrendingBloc>().add(const TrendingEvent.loadMoreFeed());
    }
  }

  bool get _isBottom {
    if (!homeScrollController.hasClients) return false;
    final maxScroll = homeScrollController.position.maxScrollExtent;
    final currentScroll = homeScrollController.offset;
    // Trigger when user is 200 pixels from bottom
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    revealHomeHeader();
    final displayCount = widget.trendingState.feedDisplayCount;
    final totalCount = widget.trendingState.feedResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.trendingState.isLoadingMoreFeed;

    return ListView.separated(
      controller: homeScrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
      separatorBuilder: (context, index) => kHeightBox10,
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index >= itemCount) {
          return _buildLoadingIndicator(hasMore, isLoading);
        }

        final feed = widget.trendingState.feedResult[index];
        final String videoId = feed.url!.split('=').last;

        final String channelId = feed.uploaderUrl!.split("/").last;
        final bool isSubscribed = widget.subscribeState.subscribedChannels
            .any((channel) => channel.id == channelId);
        return HomeVideoInfoCardWidget(
          key: ValueKey('feed_$videoId'),
          channelId: channelId,
          cardInfo: feed,
          isSubscribed: isSubscribed,
          index: index,
          onTap: () {
            BlocProvider.of<WatchBloc>(context).add(
                WatchEvent.setSelectedVideoBasicDetails(
                    details: VideoBasicInfo(
                        id: videoId,
                        title: feed.title,
                        thumbnailUrl: feed.thumbnail,
                        channelName: feed.uploaderName,
                        channelThumbnailUrl: feed.uploaderAvatar,
                        channelId: channelId,
                        uploaderVerified: feed.uploaderVerified)));
            context.goNamed('watch', pathParameters: {
              'videoId': videoId,
              'channelId': channelId,
            });
          },
          onSubscribeTap: () => onSubscribeTapped(
              context, isSubscribed, channelId, feed, widget.locals),
        );
      },
      // Add 1 for loading indicator if there's more to load
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

void onSubscribeTapped(BuildContext context, bool isSubscribed, String channelId, dynamic channelDetails, S locals) {
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

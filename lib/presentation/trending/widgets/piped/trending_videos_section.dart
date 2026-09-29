import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/home_scroll.dart';
import 'package:fluxtube/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

class TrendingVideosSection extends StatefulWidget {
  const TrendingVideosSection({
    super.key,
    required this.locals,
    required this.state,
  });

  final S locals;
  final TrendingState state;

  @override
  State<TrendingVideosSection> createState() => _TrendingVideosSectionState();
}

class _TrendingVideosSectionState extends State<TrendingVideosSection>
    with HomeListScroll {
  @override
  void onHomeScroll() {
    if (_isBottom) {
      context.read<TrendingBloc>().add(
            const TrendingEvent.loadMoreTrending(serviceType: 'piped'),
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
    final displayCount = widget.state.trendingDisplayCount;
    final totalCount = widget.state.trendingResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.state.isLoadingMoreTrending;

    return BlocBuilder<SubscribeBloc, SubscribeState>(
      buildWhen: (previous, current) =>
          previous.subscribedChannels != current.subscribedChannels,
      builder: (context, subscribeState) {
        return ListView.separated(
          controller: homeScrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          separatorBuilder: (context, index) => kHeightBox10,
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index >= itemCount) {
              return _buildLoadingIndicator(hasMore, isLoading);
            }

            final trending = widget.state.trendingResult[index];
            final String videoId = trending.url?.split('=').last ?? '';

            if (videoId.isEmpty) {
              return const SizedBox.shrink();
            }

            final String channelId =
                trending.uploaderUrl?.split("/").last ?? '';

            if (channelId.isEmpty) {
              return const SizedBox.shrink();
            }

            final bool isSubscribed = subscribeState.subscribedChannels
                .any((channel) => channel.id == channelId);
            return HomeVideoInfoCardWidget(
              key: ValueKey('trending_$videoId'),
              channelId: channelId,
              cardInfo: trending,
              isSubscribed: isSubscribed,
              index: index,
              onTap: () {
                BlocProvider.of<WatchBloc>(context).add(
                    WatchEvent.setSelectedVideoBasicDetails(
                        details: VideoBasicInfo(
                            id: videoId,
                            title: trending.title,
                            thumbnailUrl: trending.thumbnail,
                            channelName: trending.uploaderName,
                            channelThumbnailUrl: trending.uploaderAvatar,
                            channelId: channelId,
                            uploaderVerified: trending.uploaderVerified)));
                context.goNamed('watch', pathParameters: {
                  'videoId': videoId,
                  'channelId': channelId,
                });
              },
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
                              isVerified:
                                  trending.uploaderVerified ?? false)));
                }
              },
            );
          },
          itemCount: hasMore ? itemCount + 1 : itemCount,
        );
      },
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

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/home/widgets/personalized_feed_section.dart';
import 'package:fluxtube/presentation/trending/widgets/invidious/trending_videos_section.dart';
import 'package:fluxtube/presentation/trending/widgets/newpipe/trending_videos_section.dart';
import 'package:fluxtube/presentation/trending/widgets/piped/trending_videos_section.dart';
import 'package:fluxtube/widgets/widgets.dart';

import 'widgets/widgets.dart';
import 'home_scroll.dart';

class ScreenHome extends StatelessWidget {
  const ScreenHome({super.key});

  @override
  Widget build(BuildContext context) {
    final trendingBloc = BlocProvider.of<TrendingBloc>(context);
    final locals = S.of(context);

    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) =>
          previous.ytService != current.ytService ||
          previous.defaultRegion != current.defaultRegion ||
          previous.homeFeedMode != current.homeFeedMode,
      builder: (context, settingsState) {
        return SafeArea(
          child: HomeNestedScroll(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              const HomeAppBar(),
            ],
            body: BlocBuilder<SubscribeBloc, SubscribeState>(
              buildWhen: (previous, current) =>
                  previous.subscribedChannels.length !=
                  current.subscribedChannels.length,
              builder: (context, subscribeState) {
                if (subscribeState.subscribedChannels.isNotEmpty &&
                    subscribeState.oldList.length !=
                        subscribeState.subscribedChannels.length) {
                  log("oldList: ${subscribeState.oldList.length} & subscribedChannels: ${subscribeState.subscribedChannels.length}");
                  // For NewPipe, home stays as personalized feed - no refresh needed
                  // For other services, refresh the subscription feed on home
                  if (settingsState.ytService != YouTubeServices.newpipe.name) {
                    trendingBloc.add(GetForcedHomeFeedData(
                        channels: subscribeState.subscribedChannels));
                  }
                  BlocProvider.of<SubscribeBloc>(context).add(
                      SubscribeEvent.updateSubscribeOldList(
                          subscribedChannels:
                              subscribeState.subscribedChannels));
                }
                return BlocBuilder<TrendingBloc, TrendingState>(
                  buildWhen: (previous, current) {
                    return previous.fetchTrendingStatus !=
                            current.fetchTrendingStatus ||
                        previous.fetchInvidiousTrendingStatus !=
                            current.fetchInvidiousTrendingStatus ||
                        previous.fetchNewPipeTrendingStatus !=
                            current.fetchNewPipeTrendingStatus ||
                        previous.fetchFeedStatus != current.fetchFeedStatus ||
                        previous.fetchNewPipeFeedStatus !=
                            current.fetchNewPipeFeedStatus ||
                        previous.newPipeFeedResult !=
                            current.newPipeFeedResult ||
                        // Personalized feed state changes
                        previous.fetchPersonalizedFeedStatus !=
                            current.fetchPersonalizedFeedStatus ||
                        previous.personalizedFeedResult !=
                            current.personalizedFeedResult ||
                        previous.personalizedFeedDisplayCount !=
                            current.personalizedFeedDisplayCount ||
                        previous.isLoadingMorePersonalizedFeed !=
                            current.isLoadingMorePersonalizedFeed ||
                        previous.hasMorePersonalizedContent !=
                            current.hasMorePersonalizedContent ||
                        // Pagination state changes
                        previous.feedDisplayCount != current.feedDisplayCount ||
                        previous.isLoadingMoreFeed !=
                            current.isLoadingMoreFeed ||
                        previous.newPipeFeedDisplayCount !=
                            current.newPipeFeedDisplayCount ||
                        previous.isLoadingMoreNewPipeFeed !=
                            current.isLoadingMoreNewPipeFeed ||
                        previous.trendingDisplayCount !=
                            current.trendingDisplayCount ||
                        previous.isLoadingMoreTrending !=
                            current.isLoadingMoreTrending ||
                        previous.newPipeTrendingDisplayCount !=
                            current.newPipeTrendingDisplayCount ||
                        previous.isLoadingMoreNewPipeTrending !=
                            current.isLoadingMoreNewPipeTrending ||
                        previous.invidiousTrendingDisplayCount !=
                            current.invidiousTrendingDisplayCount ||
                        previous.isLoadingMoreInvidiousTrending !=
                            current.isLoadingMoreInvidiousTrending;
                  },
                  builder: (context, trendingState) {
                    if (settingsState.ytService ==
                        YouTubeServices.newpipe.name) {
                      return _buildNewPipeTrendingOrFeedSection(
                        trendingState,
                        locals,
                        context,
                        subscribeState,
                        trendingBloc,
                        settingsState,
                      );
                    } else if (settingsState.ytService ==
                        YouTubeServices.invidious.name) {
                      return _buildInvidiousTrendingOrFeedSection(
                        trendingState,
                        locals,
                        context,
                        subscribeState,
                        trendingBloc,
                        settingsState,
                      );
                    } else {
                      return _buildPipedTrendingOrFeedSection(
                        trendingState,
                        locals,
                        context,
                        subscribeState,
                        trendingBloc,
                        settingsState,
                      );
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPipedTrendingOrFeedSection(
      TrendingState trendingState,
      S locals,
      BuildContext context,
      SubscribeState subscribeState,
      TrendingBloc trendingBloc,
      SettingsState settingsState) {
    final homeFeedMode = settingsState.homeFeedMode;

    // Always fetch trending data if not available
    if (trendingState.trendingResult.isEmpty &&
        !(trendingState.fetchTrendingStatus == ApiStatus.error)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        trendingBloc.add(TrendingEvent.getTrendingData(
            serviceType: settingsState.ytService,
            region: settingsState.defaultRegion));
      });
    }

    if (trendingState.fetchTrendingStatus == ApiStatus.loading ||
        trendingState.fetchTrendingStatus == ApiStatus.initial) {
      return _buildLoadingList();
    }

    // Trending Only mode - always show trending
    if (homeFeedMode == HomeFeedMode.trendingOnly.name) {
      return _buildErrorOrTrendingSection(
        context,
        trendingState,
        locals,
        settingsState,
      );
    }

    // Feed Only mode - show feed or empty state
    if (homeFeedMode == HomeFeedMode.feedOnly.name) {
      if (trendingState.fetchFeedStatus == ApiStatus.loading) {
        return _buildLoadingList();
      }
      if (trendingState.feedResult.isEmpty) {
        return _buildEmptySubscriptionState(context, locals);
      }
      return _buildFeedSection(
        trendingState,
        locals,
        subscribeState,
        trendingBloc,
      );
    }

    // Auto mode (feedOrTrending) - show feed if available, otherwise trending
    if (trendingState.fetchFeedStatus == ApiStatus.loading) {
      return _buildLoadingList();
    }

    if (trendingState.feedResult.isEmpty ||
        trendingState.fetchFeedStatus == ApiStatus.error) {
      log("Feed Error or empty - showing trending");
      return _buildErrorOrTrendingSection(
        context,
        trendingState,
        locals,
        settingsState,
      );
    }

    return _buildFeedSection(
      trendingState,
      locals,
      subscribeState,
      trendingBloc,
    );
  }

  Widget _buildNewPipeTrendingOrFeedSection(
    TrendingState trendingState,
    S locals,
    BuildContext context,
    SubscribeState subscribeState,
    TrendingBloc trendingBloc,
    SettingsState settingsState,
  ) {
    // For NewPipe, always use personalized feed on home screen
    // (Subscription feed is available via subscriptions tab)

    // Fetch personalized feed if not already loaded
    if (trendingState.personalizedFeedResult.isEmpty &&
        trendingState.fetchPersonalizedFeedStatus == ApiStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        trendingBloc.add(TrendingEvent.getPersonalizedFeed(
          profileName: settingsState.currentProfile,
          serviceType: settingsState.ytService,
        ));
      });
    }

    if (trendingState.fetchPersonalizedFeedStatus == ApiStatus.loading ||
        trendingState.fetchPersonalizedFeedStatus == ApiStatus.initial) {
      return const ShimmerHomeVideoGrid();
    }

    // If personalized feed fails or is empty, fall back to trending
    if (trendingState.fetchPersonalizedFeedStatus == ApiStatus.error ||
        (trendingState.personalizedFeedResult.isEmpty &&
            trendingState.fetchPersonalizedFeedStatus == ApiStatus.loaded)) {
      log("Personalized feed error/empty - falling back to trending");
      // Fetch trending as fallback
      if (trendingState.newPipeTrendingResult.isEmpty &&
          trendingState.fetchNewPipeTrendingStatus != ApiStatus.loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          trendingBloc.add(TrendingEvent.getTrendingData(
              serviceType: settingsState.ytService,
              region: settingsState.defaultRegion));
        });
      }
      // Wrap with RefreshIndicator to allow retrying personalized feed
      return RefreshIndicator(
        onRefresh: () async {
          trendingBloc.add(TrendingEvent.getForcedPersonalizedFeed(
            profileName: settingsState.currentProfile,
            serviceType: settingsState.ytService,
          ));
        },
        child: _buildErrorOrTrendingSection(
          context,
          trendingState,
          locals,
          settingsState,
        ),
      );
    }

    // Show personalized feed
    return RefreshIndicator(
      onRefresh: () async {
        trendingBloc.add(TrendingEvent.getForcedPersonalizedFeed(
          profileName: settingsState.currentProfile,
          serviceType: settingsState.ytService,
        ));
      },
      child: PersonalizedFeedSection(
        trendingState: trendingState,
        locals: locals,
        settingsState: settingsState,
      ),
    );
  }

  Widget _buildInvidiousTrendingOrFeedSection(
    TrendingState trendingState,
    S locals,
    BuildContext context,
    SubscribeState subscribeState,
    TrendingBloc trendingBloc,
    SettingsState settingsState,
  ) {
    final homeFeedMode = settingsState.homeFeedMode;

    // Always fetch trending data if not available
    if (trendingState.invidiousTrendingResult.isEmpty &&
        !(trendingState.fetchInvidiousTrendingStatus == ApiStatus.error)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        trendingBloc.add(TrendingEvent.getTrendingData(
            serviceType: settingsState.ytService,
            region: settingsState.defaultRegion));
      });
    }

    if (trendingState.fetchInvidiousTrendingStatus == ApiStatus.loading ||
        trendingState.fetchInvidiousTrendingStatus == ApiStatus.initial) {
      return _buildLoadingList();
    }

    // Trending Only mode - always show trending
    if (homeFeedMode == HomeFeedMode.trendingOnly.name) {
      return _buildErrorOrTrendingSection(
        context,
        trendingState,
        locals,
        settingsState,
      );
    }

    // Feed Only mode - show feed or empty state
    if (homeFeedMode == HomeFeedMode.feedOnly.name) {
      if (trendingState.fetchFeedStatus == ApiStatus.loading) {
        return _buildLoadingList();
      }
      if (trendingState.feedResult.isEmpty) {
        return _buildEmptySubscriptionState(context, locals);
      }
      return _buildFeedSection(
        trendingState,
        locals,
        subscribeState,
        trendingBloc,
      );
    }

    // Auto mode (feedOrTrending) - show feed if available, otherwise trending
    if (trendingState.fetchFeedStatus == ApiStatus.loading) {
      return _buildLoadingList();
    }

    if (trendingState.feedResult.isEmpty ||
        trendingState.fetchFeedStatus == ApiStatus.error) {
      return _buildErrorOrTrendingSection(
        context,
        trendingState,
        locals,
        settingsState,
      );
    }

    return _buildFeedSection(
      trendingState,
      locals,
      subscribeState,
      trendingBloc,
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      separatorBuilder: (context, index) => kHeightBox10,
      itemBuilder: (context, index) {
        return const ShimmerHomeVideoInfoCard();
      },
      itemCount: 10,
    );
  }

  Widget _buildErrorOrTrendingSection(
    BuildContext context,
    TrendingState trendingState,
    S locals,
    SettingsState settingsState,
  ) {
    // NewPipe error handling
    if (settingsState.ytService == YouTubeServices.newpipe.name) {
      if (trendingState.fetchNewPipeTrendingStatus == ApiStatus.error ||
          trendingState.newPipeTrendingResult.isEmpty) {
        return ErrorRetryWidget(
          lottie: 'assets/dog.zip',
          onTap: () => BlocProvider.of<TrendingBloc>(context).add(
            TrendingEvent.getForcedTrendingData(
                serviceType: settingsState.ytService,
                region: settingsState.defaultRegion),
          ),
        );
      }
    } else if (settingsState.ytService == YouTubeServices.invidious.name) {
      if (trendingState.fetchInvidiousTrendingStatus == ApiStatus.error ||
          trendingState.invidiousTrendingResult.isEmpty) {
        return ErrorRetryWidget(
          lottie: 'assets/dog.zip',
          onTap: () => BlocProvider.of<TrendingBloc>(context).add(
            TrendingEvent.getForcedTrendingData(
                serviceType: settingsState.ytService,
                region: settingsState.defaultRegion),
          ),
        );
      }
    } else {
      if (trendingState.fetchTrendingStatus == ApiStatus.error ||
          trendingState.trendingResult.isEmpty) {
        return ErrorRetryWidget(
          lottie: 'assets/dog.zip',
          onTap: () => BlocProvider.of<TrendingBloc>(context).add(
            TrendingEvent.getForcedTrendingData(
                serviceType: settingsState.ytService,
                region: settingsState.defaultRegion),
          ),
        );
      }
    }

    // Return appropriate trending section
    if (settingsState.ytService == YouTubeServices.newpipe.name) {
      return NewPipeTrendingVideosSection(
        locals: locals,
        state: trendingState,
      );
    } else if (settingsState.ytService == YouTubeServices.invidious.name) {
      return InvidiousTrendingVideosSection(
        locals: locals,
        state: trendingState,
      );
    }

    return TrendingVideosSection(
      locals: locals,
      state: trendingState,
    );
  }

  Widget _buildFeedSection(
    TrendingState trendingState,
    S locals,
    SubscribeState subscribeState,
    TrendingBloc trendingBloc,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        trendingBloc.add(TrendingEvent.getForcedHomeFeedData(
          channels: subscribeState.subscribedChannels,
        ));
      },
      child: FeedVideoSection(
        trendingState: trendingState,
        locals: locals,
        subscribeState: subscribeState,
      ),
    );
  }

  Widget _buildEmptySubscriptionState(BuildContext context, S locals) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subscriptions_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            kHeightBox20,
            Text(
              locals.noSubscriptions,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            kHeightBox10,
            Text(
              locals.noSubscriptionsHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

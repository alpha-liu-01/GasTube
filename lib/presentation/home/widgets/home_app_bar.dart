import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/application.dart';
import '../../../core/app_info.dart';
import '../../../core/colors.dart';
import '../../../core/constants.dart';
import '../../../core/di/injectable.dart';
import '../../../core/enums.dart';
import '../../search/screen_search.dart';
import 'circular_icon.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      toolbarHeight: 60,
      elevation: 0,
      surfaceTintColor: kWhiteColor,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            AppInfo.myApp.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        Tooltip(
          message:
              MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          child: GestureDetector(
            onTap: () => _refreshHome(context),
            child: const CircularIcon(
              icon: Icons.refresh,
            ),
          ),
        ),
        kWidthBox15,
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (_) => getIt<SearchBloc>(),
              child: const ScreenSearch(),
            ),
          )),
          child: const CircularIcon(
            icon: CupertinoIcons.search,
          ),
        ),
        kWidthBox20,
      ],
    );
  }
}

void _refreshHome(BuildContext context) {
  final settings = context.read<SettingsBloc>().state;
  final trending = context.read<TrendingBloc>();
  final trendingState = trending.state;

  if (settings.ytService == YouTubeServices.newpipe.name) {
    trending.add(TrendingEvent.getForcedPersonalizedFeed(
      profileName: settings.currentProfile,
      serviceType: settings.ytService,
    ));
    return;
  }

  final mode = settings.homeFeedMode;
  final feedLoaded = trendingState.feedResult.isNotEmpty &&
      trendingState.fetchFeedStatus != ApiStatus.error;
  final feedOnScreen = mode == HomeFeedMode.feedOnly.name ||
      (mode == HomeFeedMode.feedOrTrending.name && feedLoaded);
  if (feedOnScreen) {
    trending.add(TrendingEvent.getForcedHomeFeedData(
      channels: context.read<SubscribeBloc>().state.subscribedChannels,
    ));
    return;
  }

  trending.add(TrendingEvent.getForcedTrendingData(
    serviceType: settings.ytService,
    region: settings.defaultRegion,
  ));
}

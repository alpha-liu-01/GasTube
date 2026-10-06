import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:fluxtube/widgets/card_row.dart';
import 'package:fluxtube/domain/channel/models/newpipe/newpipe_channel_resp.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_related.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_channel.dart';
import 'package:fluxtube/presentation/channel/widgets/newpipe/newpipe_channel_video_card.dart';
import 'package:go_router/go_router.dart';

class NewPipeChannelRelatedVideoSection extends StatefulWidget {
  const NewPipeChannelRelatedVideoSection({
    super.key,
    required this.channelId,
    required this.locals,
    required this.channelInfo,
    required this.state,
  });

  final S locals;
  final String channelId;
  final ChannelState state;
  final NewPipeChannelResp channelInfo;

  @override
  State<NewPipeChannelRelatedVideoSection> createState() =>
      _NewPipeChannelRelatedVideoSectionState();
}

class _NewPipeChannelRelatedVideoSectionState
    extends State<NewPipeChannelRelatedVideoSection> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  List<NewPipeRelatedStream> _allVideos = [];
  String? _nextPage;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _allVideos = List.from(widget.channelInfo.videos ?? []);
    _nextPage = widget.channelInfo.nextPage;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _nextPage != null) {
      _loadMore();
    }
  }

  Future<void> _loadUploadsPage() async {
    final channelId = widget.channelInfo.id ?? widget.channelId;
    if (_nextPage == null ||
        !channelId.startsWith('UC') ||
        channelId.length < 3) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final moreContent = await NewPipeChannel.getMorePlaylist(
        playlistId: 'UU${channelId.substring(2)}',
        nextPage: _nextPage!,
      );
      if (!mounted) return;
      setState(() {
        _allVideos.addAll(moreContent.videos ?? []);
        _nextPage = moreContent.nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextPage == null || _isLoadingMore) return;

    final videosTab = widget.channelInfo.tabs?.firstWhere(
      (t) => t.name?.toLowerCase() == 'videos',
      orElse: () => widget.channelInfo.tabs?.first ?? NewPipeChannelTab(),
    );
    final url = videosTab?.url;
    if (url == null || videosTab == null) {
      await _loadUploadsPage();
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreContent = await NewPipeChannel.getChannelTabWithPagination(
        url,
        nextPage: _nextPage!,
        tabId: videosTab.id,
        contentFilters: videosTab.contentFilters,
      );

      if (!mounted) return;
      setState(() {
        _allVideos.addAll(moreContent.videos ?? []);
        _nextPage = moreContent.nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show empty state if no videos
    if (_allVideos.isEmpty && !_isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                widget.locals.noVideosFound,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth.isFinite
            ? WindowLayout.cardColumns(constraints.maxWidth)
            : 1;
        if (columns == 1) {
          return ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) =>
                _videoItem(context, index, aspectRatioThumbnail: false),
            separatorBuilder: (context, index) => kWidthBox10,
            itemCount: _allVideos.length + (_isLoadingMore ? 1 : 0),
          );
        }
        final rowCount = (_allVideos.length / columns).ceil();
        return ListView.builder(
          controller: _scrollController,
          itemCount: rowCount + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, row) {
            if (row >= rowCount) return _loadingMore();
            final start = row * columns;
            return CardRow(
              columns: columns,
              children: [
                for (var column = 0;
                    column < columns && start + column < _allVideos.length;
                    column++)
                  _videoItem(
                    context,
                    start + column,
                    aspectRatioThumbnail: true,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _loadingMore() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _videoItem(
    BuildContext context,
    int index, {
    required bool aspectRatioThumbnail,
  }) {
    if (index >= _allVideos.length) {
      return _isLoadingMore ? _loadingMore() : const SizedBox();
    }
    final NewPipeRelatedStream videoInfo = _allVideos[index];
    // NewPipe uses url like "/watch?v=VIDEO_ID"
    final String videoId = videoInfo.url?.split('=').last ?? '';
    // uploaderUrl is like "/channel/CHANNEL_ID"
    final String videoChannelId =
        videoInfo.uploaderUrl?.split("/").last ?? widget.channelId;

    return NewPipeChannelVideoCard(
      videoInfo: videoInfo,
      channelId: videoChannelId,
      subscribeRowVisible: false,
      index: index,
      aspectRatioThumbnail: aspectRatioThumbnail,
      onTap: () {
        BlocProvider.of<WatchBloc>(context).add(
            WatchEvent.setSelectedVideoBasicDetails(
                details: VideoBasicInfo(
                    id: videoId,
                    title: videoInfo.name,
                    thumbnailUrl: videoInfo.thumbnailUrl,
                    channelName: videoInfo.uploaderName,
                    channelThumbnailUrl: videoInfo.uploaderAvatarUrl,
                    channelId: videoChannelId,
                    uploaderVerified: videoInfo.uploaderVerified)));
        context.pushNamed('watch', pathParameters: {
          'videoId': videoId,
          'channelId': videoChannelId,
        });
      },
    );
  }
}

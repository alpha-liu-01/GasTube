import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/watch/watch_bloc.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:go_router/go_router.dart';

/// Opens [video] from the playback queue.
void openQueuedVideo(BuildContext context, VideoBasicInfo video) {
  if (!context.mounted || video.id.isEmpty) return;
  PlaybackQueue().syncCurrent(video.id);
  BlocProvider.of<WatchBloc>(context).add(
    WatchEvent.setSelectedVideoBasicDetails(details: video),
  );
  context.goNamed('watch', pathParameters: {
    'videoId': video.id,
    'channelId': video.channelId ?? '',
  });
}

/// Opens the previous or next queued video. Returns false when there is none.
bool playQueueNeighbor(BuildContext context, {required bool next}) {
  if (!context.mounted) return false;
  final currentId = GlobalPlayerController().currentVideoId;
  final queue = PlaybackQueue();
  final video =
      next ? queue.nextAfter(currentId) : queue.previousAfter(currentId);
  if (video == null || video.id.isEmpty || video.id == currentId) return false;
  openQueuedVideo(context, video);
  return true;
}

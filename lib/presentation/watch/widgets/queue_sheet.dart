import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/watch/watch_bloc.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/watch/queue_playback.dart';
import 'package:fluxtube/widgets/thumbnail_image.dart';
import 'package:go_router/go_router.dart';

/// The playback queue on the watch page.
///
/// The in-app player used to open this list from its own controls. Those
/// controls are not on screen after a system-player handoff, so the same
/// list sits under the preview.
class WatchQueuePanel extends StatelessWidget {
  const WatchQueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaybackQueue(),
      builder: (context, _) {
        final playbackQueue = PlaybackQueue();
        final queue = playbackQueue.queue;
        final current = playbackQueue.currentIndex;
        final locals = S.of(context);
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    locals.queue,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${queue.length})',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (queue.length > 2)
                    TextButton(
                      onPressed: playbackQueue.shuffle,
                      child: Text(locals.queueShuffle),
                    ),
                  if (queue.isNotEmpty)
                    TextButton(
                      onPressed: playbackQueue.clear,
                      child: Text(locals.queueClear),
                    ),
                ],
              ),
              if (queue.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    locals.queueEmpty,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (var index = 0; index < queue.length; index++)
                  _QueueTile(
                    video: queue[index],
                    current: index == current,
                    onRemove: () => playbackQueue.removeAt(index),
                    onTap: index == current
                        ? null
                        : () {
                            PlaybackQueue().moveTo(index);
                            openQueuedVideo(context, queue[index]);
                          },
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.video,
    required this.current,
    required this.onRemove,
    required this.onTap,
  });

  final VideoBasicInfo video;
  final bool current;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locals = S.of(context);
    final url = video.thumbnailUrl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
      leading: url == null || url.isEmpty
          ? const SizedBox(width: 64, height: 36)
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ThumbnailImage.small(
                url: url,
                width: 64,
                height: 36,
              ),
            ),
      title: Text(
        video.title ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        video.channelName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: locals.removeFromQueue,
        onPressed: onRemove,
      ),
    );
  }
}

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key, this.onVideoSelected});

  /// Overrides the default behaviour of navigating to the tapped video.
  final Function(VideoBasicInfo)? onVideoSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaybackQueue(),
      builder: (context, _) {
        final playbackQueue = PlaybackQueue();
        final queue = playbackQueue.queue;
        final current = playbackQueue.currentIndex;
        final locals = S.of(context);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF212121),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(locals.queue,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('(${queue.length})',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      const Spacer(),
                      if (queue.length > 2)
                        TextButton(
                          onPressed: playbackQueue.shuffle,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(locals.queueShuffle,
                              style: TextStyle(fontSize: 13)),
                        ),
                      if (queue.isNotEmpty)
                        TextButton(
                          onPressed: playbackQueue.clear,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child:
                              Text(locals.queueClear, style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (queue.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(locals.queueEmpty,
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final video = queue[index];
                        final isCurrent = index == current;

                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: _buildThumbnail(video),
                          title: Text(
                            video.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                              color: isCurrent ? Colors.white : Colors.white70,
                            ),
                          ),
                          subtitle: Text(
                            video.channelName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white54),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.white38,
                            tooltip: locals.removeFromQueue,
                            onPressed: () => playbackQueue.removeAt(index),
                          ),
                          onTap: isCurrent
                              ? () => Navigator.of(context).pop()
                              : () => _play(context, video, index),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(VideoBasicInfo video) {
    final url = video.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const SizedBox(width: 48, height: 27);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        url,
        width: 48,
        height: 27,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 27),
      ),
    );
  }

  /// Moves the cursor and actually opens the video. Without the navigation the
  /// tap only reorders internal state and nothing appears to happen.
  void _play(BuildContext context, VideoBasicInfo video, int index) {
    // Resolve both before popping — the sheet context is defunct afterwards.
    final watchBloc = BlocProvider.of<WatchBloc>(context);
    final router = GoRouter.of(context);

    PlaybackQueue().moveTo(index);
    Navigator.of(context).pop();

    if (onVideoSelected != null) {
      onVideoSelected!(video);
      return;
    }

    watchBloc.add(WatchEvent.setSelectedVideoBasicDetails(details: video));
    router.goNamed('watch', pathParameters: {
      'videoId': video.id,
      'channelId': video.channelId ?? '',
    });
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

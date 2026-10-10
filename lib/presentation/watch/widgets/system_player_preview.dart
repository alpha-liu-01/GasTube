import 'package:flutter/material.dart';
import 'package:fluxtube/core/operations/math_operations.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/presentation/watch/queue_playback.dart';
import 'package:fluxtube/widgets/thumbnail_image.dart';

/// Still picture for a video that is already in the system player.
///
/// The watch page and the mini window both use this. Tapping [onPlay] is the
/// only way back into the system player. The mini window leaves [onPlay] null
/// so returning to the page does not charge a new session.
class SystemPlayerPreview extends StatelessWidget {
  const SystemPlayerPreview({
    super.key,
    required this.videoId,
    this.thumbnailUrl,
    this.onPlay,
    this.finished = false,
    this.onBackground,
    this.qualityLabel,
    this.onQuality,
  });

  final String videoId;
  final String? thumbnailUrl;
  final VoidCallback? onPlay;

  /// The system player reached the end, so [onPlay] starts this video again.
  final bool finished;

  /// Arms this video's audio for when the user leaves. The mini window leaves
  /// this null.
  final VoidCallback? onBackground;

  /// Label for this video only. The mini window leaves [onQuality] null.
  final String? qualityLabel;
  final VoidCallback? onQuality;

  @override
  Widget build(BuildContext context) {
    final player = GlobalPlayerController();
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final matched = player.systemPlayerHandoffFor(videoId);
        final frame = matched ? player.systemPlayerFrame : null;
        final storedCover = matched ? player.systemPlayerThumbnail : null;
        final cover = (storedCover != null && storedCover.isNotEmpty)
            ? storedCover
            : thumbnailUrl;
        final position =
            matched ? player.systemPlayerPosition : Duration.zero;
        final backgroundArmed = player.backgroundAudioEnabled;
        return ColoredBox(
          color: Colors.black,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (frame != null)
                    Image.memory(
                      frame,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    )
                  else if (cover != null && cover.isNotEmpty)
                    ThumbnailImage(
                      url: cover,
                      fit: BoxFit.cover,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                  if (position >= const Duration(seconds: 1))
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCC000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              formatDuration(position.inSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onPlay != null)
                    Center(
                      child: ListenableBuilder(
                        listenable: PlaybackQueue(),
                        builder: (context, _) {
                          final queue = PlaybackQueue();
                          final previous = queue.previousAfter(videoId);
                          final next = queue.nextAfter(videoId);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _QueueStepButton(
                                icon: Icons.skip_previous,
                                onPressed: previous == null
                                    ? null
                                    : () {
                                        playQueueNeighbor(
                                          context,
                                          next: false,
                                          currentId: videoId,
                                        );
                                      },
                              ),
                              IconButton(
                                iconSize: 72,
                                color: Colors.white,
                                icon: Icon(
                                  finished
                                      ? Icons.replay
                                      : Icons.play_circle_fill,
                                ),
                                onPressed: onPlay,
                              ),
                              _QueueStepButton(
                                icon: Icons.skip_next,
                                onPressed: next == null
                                    ? null
                                    : () {
                                        playQueueNeighbor(
                                          context,
                                          next: true,
                                          currentId: videoId,
                                        );
                                      },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (onBackground != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: backgroundArmed
                              ? Colors.white
                              : const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: onBackground,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.headset,
                                size: 20,
                                color: backgroundArmed
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onQuality != null &&
                      qualityLabel != null &&
                      qualityLabel!.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.55,
                          ),
                          child: Material(
                            color: const Color(0xCC000000),
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: onQuality,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  qualityLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _QueueStepButton extends StatelessWidget {
  const _QueueStepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 36,
        color: Colors.white,
        disabledColor: const Color(0x66FFFFFF),
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

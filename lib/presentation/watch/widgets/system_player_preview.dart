import 'package:flutter/material.dart';
import 'package:fluxtube/core/operations/math_operations.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
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
  });

  final String videoId;
  final String? thumbnailUrl;
  final VoidCallback? onPlay;

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
                      child: IconButton(
                        iconSize: 72,
                        color: Colors.white,
                        icon: const Icon(Icons.play_circle_fill),
                        onPressed: onPlay,
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

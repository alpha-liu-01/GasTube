import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

/// Plays a finished download with the same media_kit player used for YouTube.
class LocalFilePlayerPage extends StatefulWidget {
  const LocalFilePlayerPage({
    super.key,
    required this.path,
    required this.title,
  });

  final String path;
  final String title;

  @override
  State<LocalFilePlayerPage> createState() => _LocalFilePlayerPageState();
}

class _LocalFilePlayerPageState extends State<LocalFilePlayerPage> {
  final GlobalPlayerController _globalPlayer = GlobalPlayerController();
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_open());
    });
  }

  Future<void> _open() async {
    try {
      final player = _globalPlayer.player;
      final codec = await _probeVideoCodec(widget.path);
      if (UbuntuTouch.enabled) {
        await (player.platform as dynamic).setProperty('ao', 'pulse');
        await selectUbuntuTouchDecoder(player, codec: codec);
      }
      print('gastube: local play file=${widget.path} codec=$codec');
      await player.open(Media(widget.path), play: true);
      _globalPlayer.setCurrentVideoId('local:${widget.path}', videoUrl: widget.path);
      print('gastube: local play opened file=${widget.path}');
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      print('gastube: local play failed file=${widget.path} error=$error');
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    unawaited(_globalPlayer.stopAndClear());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _ready
              ? Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(
                      controller: _globalPlayer.videoController,
                      controls: MaterialVideoControls,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

Future<String?> _probeVideoCodec(String path) async {
  final ffmpeg = p.join(p.dirname(Platform.resolvedExecutable), 'ffmpeg');
  if (!File(ffmpeg).existsSync()) return null;
  try {
    final result = await Process.run(ffmpeg, ['-hide_banner', '-i', path]);
    final text = '${result.stdout}\n${result.stderr}';
    if (text.contains('Video: vp9') || text.contains('Video: vp09')) return 'vp9';
    if (text.contains('Video: h264') || text.contains('Video: avc1')) return 'h264';
  } catch (error) {
    print('gastube: local play probe failed file=$path error=$error');
  }
  return null;
}

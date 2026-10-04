import 'dart:async';
import 'dart:io';

import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/services/audio_handler_service.dart';
import 'package:fluxtube/core/services/mpris_player.dart';

/// What is on screen now, plus the commands a system session may send later.
///
/// The player still starts, pauses, and seeks itself. This only publishes that
/// state. Android hands it to [FluxTubeAudioHandler]. Desktop Linux and Ubuntu
/// Touch keep it here until MPRIS is connected.
class NowPlaying {
  const NowPlaying({
    required this.id,
    required this.title,
    required this.artist,
    this.artUri,
    this.duration,
    this.position = Duration.zero,
    this.playing = false,
  });

  final String id;
  final String title;
  final String artist;
  final String? artUri;
  final Duration? duration;
  final Duration position;
  final bool playing;
}

abstract class MediaControls {
  static MediaControls? _instance;

  static MediaControls get instance {
    return _instance ??= Platform.isLinux
        ? LocalMediaControls()
        : AudioServiceMediaControls();
  }

  NowPlaying? get nowPlaying;

  Future<void> setNowPlaying({
    required String id,
    required String title,
    required String artist,
    String? artUri,
    Duration? duration,
    bool external = false,
  });

  Future<void> updateProgress({
    required bool playing,
    required Duration position,
    required Duration duration,
    bool buffering = false,
    double speed = 1.0,
  });

  void bindCommands({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    Future<void> Function()? stop,
    Future<void> Function(Duration position)? seek,
  });

  /// Commands a system session calls. MPRIS uses these on Linux.
  Future<void> sessionPlay();
  Future<void> sessionPause();
  Future<void> sessionSeek(Duration position);
  Future<void> sessionStop();

  Future<void> clear();
}

/// Android, and any desktop that still uses audio_service.
class AudioServiceMediaControls implements MediaControls {
  bool _external = false;

  @override
  NowPlaying? nowPlaying;

  @override
  Future<void> setNowPlaying({
    required String id,
    required String title,
    required String artist,
    String? artUri,
    Duration? duration,
    bool external = false,
  }) async {
    final handler = await ensureAudioServiceInitialized();
    if (handler == null) return;
    _external = external;
    nowPlaying = NowPlaying(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration,
    );
    if (external) {
      await handler.setExternalMediaItem(
        id: id,
        title: title,
        artist: artist,
        artUri: artUri,
        duration: duration,
      );
    } else {
      await handler.setMediaItem(
        id: id,
        title: title,
        artist: artist,
        artUri: artUri,
        duration: duration,
      );
    }
  }

  @override
  Future<void> updateProgress({
    required bool playing,
    required Duration position,
    required Duration duration,
    bool buffering = false,
    double speed = 1.0,
  }) async {
    final current = nowPlaying;
    if (current != null) {
      nowPlaying = NowPlaying(
        id: current.id,
        title: current.title,
        artist: current.artist,
        artUri: current.artUri,
        duration: duration,
        position: position,
        playing: playing,
      );
    }
    if (!_external) return;
    final handler = await ensureAudioServiceInitialized();
    await handler?.updateExternalPlaybackState(
      playing: playing,
      position: position,
      duration: duration,
      buffering: buffering,
      speed: speed,
    );
  }

  @override
  void bindCommands({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    Future<void> Function()? stop,
    Future<void> Function(Duration position)? seek,
  }) {
    unawaited(() async {
      final handler = await ensureAudioServiceInitialized();
      handler?.configureExternalControls(
        play: play,
        pause: pause,
        stop: stop,
        seek: seek,
      );
    }());
  }

  @override
  Future<void> sessionPlay() async {
    await getAudioHandler()?.play();
  }

  @override
  Future<void> sessionPause() async {
    await getAudioHandler()?.pause();
  }

  @override
  Future<void> sessionSeek(Duration position) async {
    await getAudioHandler()?.seek(position);
  }

  @override
  Future<void> sessionStop() async {
    await getAudioHandler()?.stop();
  }

  @override
  Future<void> clear() async {
    nowPlaying = null;
    _external = false;
    await getAudioHandler()?.clearMedia();
  }
}

/// Holds the current item and publishes it on the MPRIS session bus.
class LocalMediaControls implements MediaControls {
  bool _external = false;
  bool _listening = false;
  bool _announced = false;
  bool buffering = false;
  double speed = 1.0;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  Future<void> Function()? play;
  Future<void> Function()? pause;
  Future<void> Function()? stop;
  Future<void> Function(Duration position)? seek;

  @override
  NowPlaying? nowPlaying;

  void _listenToPlayer() {
    if (_listening) return;
    final controller = GlobalPlayerController();
    if (!controller.hasActiveMediaKitPlayer) return;
    final player = controller.player;
    _listening = true;
    _playingSubscription = player.stream.playing.listen((playing) {
      final current = nowPlaying;
      if (_external || current == null || current.playing == playing) return;
      nowPlaying = NowPlaying(
        id: current.id,
        title: current.title,
        artist: current.artist,
        artUri: current.artUri,
        duration: current.duration,
        position: current.position,
        playing: playing,
      );
      print('gastube: media playing=$playing id=${current.id}');
      MprisPlayer.instance.note(nowPlaying);
    });
    _positionSubscription = player.stream.position.listen((position) {
      final current = nowPlaying;
      if (_external || current == null) return;
      final jump = (position - current.position).inMilliseconds.abs();
      nowPlaying = NowPlaying(
        id: current.id,
        title: current.title,
        artist: current.artist,
        artUri: current.artUri,
        duration: current.duration,
        position: position,
        playing: current.playing,
      );
      MprisPlayer.instance.note(nowPlaying, seeked: jump > 2000);
    });
    _durationSubscription = player.stream.duration.listen((duration) {
      final current = nowPlaying;
      if (_external || current == null || duration <= Duration.zero) return;
      nowPlaying = NowPlaying(
        id: current.id,
        title: current.title,
        artist: current.artist,
        artUri: current.artUri,
        duration: duration,
        position: current.position,
        playing: current.playing,
      );
      MprisPlayer.instance.note(nowPlaying);
    });
  }

  @override
  Future<void> setNowPlaying({
    required String id,
    required String title,
    required String artist,
    String? artUri,
    Duration? duration,
    bool external = false,
  }) async {
    _external = external;
    nowPlaying = NowPlaying(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration,
    );
    if (!external) _listenToPlayer();
    if (!_announced) {
      _announced = true;
      print('gastube: media controls local');
    }
    print('gastube: media now id=$id title=$title');
    MprisPlayer.instance.note(nowPlaying);
  }

  @override
  Future<void> updateProgress({
    required bool playing,
    required Duration position,
    required Duration duration,
    bool buffering = false,
    double speed = 1.0,
  }) async {
    final current = nowPlaying;
    if (current == null) return;
    this.buffering = buffering;
    this.speed = speed;
    if (current.playing != playing) {
      print(
        'gastube: media playing=$playing buffering=$buffering speed=$speed id=${current.id}',
      );
    }
    nowPlaying = NowPlaying(
      id: current.id,
      title: current.title,
      artist: current.artist,
      artUri: current.artUri,
      duration: duration,
      position: position,
      playing: playing,
    );
    MprisPlayer.instance.note(nowPlaying);
  }

  @override
  void bindCommands({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    Future<void> Function()? stop,
    Future<void> Function(Duration position)? seek,
  }) {
    this.play = play;
    this.pause = pause;
    this.stop = stop;
    this.seek = seek;
  }

  @override
  Future<void> sessionPlay() async {
    final command = play;
    if (command != null) {
      await command();
      return;
    }
    if (_external || nowPlaying == null) return;
    await GlobalPlayerController().player.play();
  }

  @override
  Future<void> sessionPause() async {
    final command = pause;
    if (command != null) {
      await command();
      return;
    }
    if (_external || nowPlaying == null) return;
    await GlobalPlayerController().player.pause();
  }

  @override
  Future<void> sessionSeek(Duration position) async {
    final command = seek;
    if (command != null) {
      await command(position);
      return;
    }
    if (_external || nowPlaying == null) return;
    await GlobalPlayerController().player.seek(position);
  }

  @override
  Future<void> sessionStop() async {
    final command = stop;
    if (command != null) {
      await command();
    }
  }

  @override
  Future<void> clear() async {
    nowPlaying = null;
    _external = false;
    buffering = false;
    speed = 1.0;
    play = null;
    pause = null;
    stop = null;
    seek = null;
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _playingSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;
    _listening = false;
    print('gastube: media clear');
    MprisPlayer.instance.note(null);
  }
}

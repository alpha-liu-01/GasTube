import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/ubuntu_touch_content_hub.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_channel.dart';
import 'package:path/path.dart' as p;

/// Plays one audio URL through Lomiri media-hub while this process is away.
///
/// The session is opened while the app is still in front, because leaving only
/// delivers [AppLifecycleState.inactive] and Lomiri then stops the process.
/// In-app playback stays on mpv with `ao=pulse` until that moment. The sound
/// indicator then follows this media-hub session. Its previous and next
/// buttons step the session track list. Desktop builds never call this bus.
class MediaHubPlayer {
  static final MediaHubPlayer instance = MediaHubPlayer._();

  MediaHubPlayer._();

  static const _serviceName = 'com.lomiri.MediaHub.Service';
  static const _servicePath = '/com/lomiri/MediaHub/Service';
  static const _playerInterface = 'org.mpris.MediaPlayer2.Player';
  static const _trackInterface = 'org.mpris.MediaPlayer2.TrackList';
  static const _noTrack = '/org/mpris/MediaPlayer2/TrackList/NoTrack';
  static const _sessionChannel = MethodChannel('lol.alphaliu01.gastube/url');

  final GlobalPlayerController _player = GlobalPlayerController();
  DBusClient? _client;
  DBusRemoteObject? _session;
  String? _uuid;
  String? _openedUrl;
  bool _ready = false;
  bool _away = false;
  bool _pageAudio = false;
  int _sliceEpoch = 0;
  int? _sliceMediaStart;
  int? _sliceSidxOffset;
  int? _sliceGrabBytes;
  int? _sliceUntilUs;
  bool _extendPending = false;
  bool _didExtend = false;
  bool _replacedByFull = false;
  DateTime _extendChecked = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _heardUntil = Duration.zero;
  DateTime? _awaySince;
  _ExtendOffer? _extendOffer;
  bool _extendRunning = false;
  bool _hubKnown = false;

  /// The armed m4a is already playing on this page. A rebuild must not seek it.
  bool get holdsPageAudio => _pageAudio;
  Duration _pausedAt = Duration.zero;
  Future<void> _queue = Future<void>.value();
  String? _cachedUrl;
  String? _cachedFile;
  String? _downloadingUrl;
  String? _rejectedUrl;
  int? _jumpTo;
  bool _usingSlice = false;
  Duration? _sliceFrom;
  final Set<String> _extraDownloads = {};
  final Map<String, String> _trackFiles = {};
  final Map<String, String> _trackIds = {};
  StreamSubscription<DBusSignal>? _trackChanged;
  String? _indicatorVideoId;
  bool _anchored = false;
  String? _returnVideoId;
  Duration? _returnPosition;
  void Function(String videoId)? _onIndicatorReturn;

  /// The watch screen registers this so returning from the indicator can open
  /// the video the track list moved to.
  void bindIndicatorReturn(void Function(String videoId)? callback) {
    _onIndicatorReturn = callback;
  }

  void unbindIndicatorReturn(void Function(String videoId) callback) {
    if (!identical(_onIndicatorReturn, callback)) return;
    _onIndicatorReturn = null;
  }

  /// Position to start [videoId] when it was opened from the indicator.
  Duration? takeReturnPosition(String videoId) {
    if (_returnVideoId != videoId) return null;
    final position = _returnPosition;
    _returnVideoId = null;
    _returnPosition = null;
    return position;
  }

  /// Open the current audio URL without playing it, and start saving a local
  /// copy. media-hub can seek a local file. Seeking the YouTube URL ends it.
  bool urlWasRejected(String? url) =>
      url != null && url.isNotEmpty && url == _rejectedUrl;

  Future<void> prepare() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    final url = _player.backgroundAudioUrl;
    // The armed page starts at the saved position. A download from byte 0
    // and a remote open both fight that range request and leave a short clip.
    if (url != null && !_player.backgroundAudioArmed) {
      unawaited(_cacheAudio(url));
    }
    return _enqueue(_prepare);
  }

  /// media-hub starts the sound, then local playback stops.
  Future<void> handoff() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(() => _handoff());
  }

  /// Starts the armed m4a while this page is still open.
  Future<void> playOnPage() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(() => _handoff(onPage: true));
  }

  /// Writes the live hub position onto the system-player bookmark.
  ///
  /// Opening the system player reads that bookmark, so a listen on this page
  /// is not thrown away.
  Future<void> stampArmedPosition() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(_stampArmedPosition);
  }

  Future<void> takeBack() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(_takeBack);
  }

  Future<void> stop() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    // This playback is over. Remember the cache files now, before the next
    // video starts writing new ones, and delete them after media-hub lets go.
    _downloadingUrl = null;
    _sliceEpoch++;
    _extendPending = false;
    _didExtend = false;
    _replacedByFull = false;
    _heardUntil = Duration.zero;
    _awaySince = null;
    _extendOffer = null;
    _extendRunning = false;
    _hubKnown = false;
    _trackFiles.clear();
    final stale = _backgroundAudioFiles();
    return _enqueue(() async {
      await _dropSession();
      _removeSessionCache(stale);
    });
  }

  /// Pause the hub session when headphones are unplugged while it owns the
  /// sound. Returns false when in-app playback is the thing to pause.
  Future<bool> pauseIfAway() async {
    if (!UbuntuTouch.enabled) return false;
    var paused = false;
    await _enqueue(() async {
      if (!_away && !_pageAudio) return;
      await _pauseHub();
      paused = true;
      if (_pageAudio) {
        _pageAudio = false;
        _player.setBackgroundAudioEnabled(false);
        _player.forgetBackgroundAudio();
      }
      print('gastube: pulse unplug hub');
    });
    return paused;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final done = _queue.then((_) => action());
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<void> _prepare() async {
    if (_away || _player.backgroundAudioArmed) return;
    unawaited(_prepareNeighbors());
    final url = _player.backgroundAudioUrl;
    if (url == null) return;
    if (_ready && _openedUrl == url) return;
    await _open(url);
  }

  Future<void> _handoff({bool onPage = false}) async {
    if (_away) return;
    final videoId = _player.currentVideoId;
    final armed = _player.backgroundAudioArmed &&
        videoId != null &&
        _player.systemPlayerHandoffFor(videoId);
    // A scroll rebuilds this page and asks again. The bookmark is the moment
    // the system player was left, so seeking there jumps backward.
    if (onPage && _pageAudio && armed) return;
    if (!onPage && _pageAudio && armed) {
      _pausedAt = await _hubPosition();
      _away = true;
      _pageAudio = false;
      _awaySince = DateTime.now();
      print(
        'gastube: background audio keep '
        'positionMs=${_pausedAt.inMilliseconds}',
      );
      return;
    }
    if (!armed && !_player.isPlaying) return;
    // A cleared video can still report playing for a moment. The last opened
    // URL must not start again after the user has left that video.
    final url = _player.backgroundAudioUrl;
    if (url == null || videoId == null) {
      print(
        'gastube: mediahub skip '
        'reason=${videoId == null ? "no-video" : "no-audio-url"}',
      );
      return;
    }
    _pausedAt = armed ? _player.systemPlayerPosition : _player.currentPosition;
    if (!onPage) _away = true;
    unawaited(_prepareNeighbors());
    print(
      'gastube: mediahub handoff host=${Uri.tryParse(url)?.host ?? "unknown"} '
      'positionMs=${_pausedAt.inMilliseconds} ready=$_ready',
    );
    var playingOnHub = false;
    try {
      var local = _readyLocal(url);
      _usingSlice = false;
      _sliceFrom = null;
      if (!armed) local ??= _snapshotLocal(url, _pausedAt);
      var extendEpoch = 0;
      if (local == null) {
        if (armed) {
          _downloadingUrl = null;
          _sliceEpoch++;
          _didExtend = false;
          _extendPending = false;
          _replacedByFull = false;
          _heardUntil = _pausedAt;
        }
        extendEpoch = _sliceEpoch;
        local = await _sliceLocal(url, _pausedAt, fast: armed);
        _usingSlice = local != null;
        if (armed && !_player.backgroundAudioArmed) return;
      }
      var seekLocal = false;
      if (local != null) {
        print('gastube: mediahub local bytes=${File(local).lengthSync()}');
        await _open(Uri.file(local).toString());
        if (_ready && _session != null) {
          seekLocal = true;
        } else {
          print('gastube: mediahub local open failed');
          await _open(url);
        }
      } else {
        print('gastube: mediahub local missing');
        if (!_ready || _openedUrl != url || _session == null) {
          await _open(url);
        }
      }
      var session = _session;
      if (session == null || !_ready) {
        throw StateError('open failed');
      }
      if (seekLocal) {
        final sought = await _seekLocal(session);
        if (!sought && _usingSlice && local != null) {
          print('gastube: mediahub slice seek failed');
          await _open(Uri.file(local).toString());
          session = _session;
          if (session == null || !_ready) throw StateError('open failed');
        } else if (!sought) {
          print('gastube: mediahub local seek failed');
          await _open(url);
          session = _session;
          if (session == null || !_ready) throw StateError('open failed');
        }
      } else if (await _playbackStatus(session) == 'Stopped') {
        print('gastube: mediahub reopen reason=stopped');
        await _open(url);
        session = _session;
        if (session == null || !_ready) throw StateError('open failed');
      }
      await session.callMethod(_playerInterface, 'Play', const []);
      var status = await _untilPlaying(session);
      if (status != 'Playing' && seekLocal && _sliceFrom != null) {
        print('gastube: mediahub play stalled status=$status');
        final saved = _pausedAt;
        _pausedAt = _sliceFrom!;
        await _seekLocal(session);
        _pausedAt = saved;
        await session.callMethod(_playerInterface, 'Play', const []);
        status = await _untilPlaying(session);
      }
      print('gastube: mediahub play status=$status');
      if (status == 'Playing') {
        playingOnHub = true;
        if (onPage) {
          _pageAudio = true;
          _away = false;
          print(
            'gastube: background audio play '
            'positionMs=${_pausedAt.inMilliseconds}',
          );
        }
        if (armed && _usingSlice && extendEpoch == _sliceEpoch) {
          if (_pausedAt > _heardUntil) _heardUntil = _pausedAt;
          unawaited(_extendArmed(url, extendEpoch));
          unawaited(_followArmedClock(url, extendEpoch));
        }
        await _player.pausePlayback();
        await _attachIndicatorTracks(anchor: true);
        final current = _session;
        if (current != null && await _playbackStatus(current) != 'Playing') {
          await current.callMethod(_playerInterface, 'Play', const []);
          print('gastube: mediahub play after indicator');
        }
      } else {
        print('gastube: mediahub play not started');
        _away = false;
        _pageAudio = false;
        if (onPage) _player.forgetBackgroundAudio();
      }
    } catch (error) {
      print('gastube: mediahub failed error=$error');
      if (!playingOnHub) {
        _away = false;
        if (onPage) {
          _pageAudio = false;
          _player.forgetBackgroundAudio();
        }
      }
    }
  }

  Future<void> _stampArmedPosition() async {
    if (!_pageAudio && !_away) return;
    if (!_player.backgroundAudioArmed) return;
    final url = _player.systemPlayerHandoffUrl;
    if (url == null || url.isEmpty) return;
    final at = await _hubPosition();
    final best = at > _heardUntil ? at : _heardUntil;
    if (best <= Duration.zero) return;
    await noteSystemPlayerBookmark(url, best);
    _player.updateSystemPlayerHandoffPosition(best);
    print('gastube: background audio stamp positionMs=${best.inMilliseconds}');
  }

  Future<void> _takeBack() async {
    if (!_away) return;
    final hubAt = await _hubPosition();
    final known = _hubKnown;
    final awayFor = _awaySince == null
        ? Duration.zero
        : DateTime.now().difference(_awaySince!);
    final cover = Duration(microseconds: _sliceUntilUs ?? 0);
    final left = cover > _pausedAt ? cover - _pausedAt : Duration.zero;
    // While this process is stopped, media-hub can only play the file it
    // already has open. Once that file ends the session resets, and the
    // position read falls back to the lock stamp. Continuing from that stamp
    // rewinds to the lock. The audio died at the end of the open file.
    final fileEnded = _usingSlice &&
        cover > _pausedAt &&
        left > const Duration(seconds: 1) &&
        awayFor > left &&
        awayFor > const Duration(seconds: 3) &&
        (!known || hubAt + const Duration(seconds: 2) < _pausedAt);
    var resumeAt = hubAt >= _pausedAt ? hubAt : _pausedAt;
    if (fileEnded) resumeAt = cover;
    if (resumeAt > _heardUntil) _heardUntil = resumeAt;
    final session = _session;
    final status = session == null ? null : await _playbackStatus(session);
    final stayPaused = status == 'Paused';
    final currentIdEarly = _player.currentVideoId;
    final keepPageAudio = !stayPaused &&
        _player.backgroundAudioArmed &&
        currentIdEarly != null &&
        _player.systemPlayerHandoffFor(currentIdEarly);
    final jumped = _indicatorVideoId;
    final currentId = currentIdEarly;
    if (jumped != null &&
        jumped != currentId &&
        _onIndicatorReturn != null) {
      await _pauseHub();
      _pageAudio = false;
      _returnVideoId = jumped;
      _returnPosition = resumeAt;
      _indicatorVideoId = null;
      _away = false;
      print(
        'gastube: mediahub back video=$jumped '
        'positionMs=${resumeAt.inMilliseconds}',
      );
      _onIndicatorReturn!(jumped);
      return;
    }
    if (_player.backgroundAudioArmed &&
        currentId != null &&
        _player.systemPlayerHandoffFor(currentId)) {
      _away = false;
      final handoffUrl = _player.systemPlayerHandoffUrl;
      if (handoffUrl != null && resumeAt > Duration.zero) {
        await noteSystemPlayerBookmark(handoffUrl, resumeAt);
      }
      _player.updateSystemPlayerHandoffPosition(resumeAt);
      if (stayPaused || !keepPageAudio) {
        _pageAudio = false;
        _player.forgetBackgroundAudio();
        await _dropSession();
        print('gastube: background audio paused');
      } else {
        _pageAudio = true;
        _awaySince = null;
        final stalled = !fileEnded &&
            awayFor > const Duration(seconds: 3) &&
            known &&
            (hubAt - _pausedAt).inMilliseconds.abs() < 1500;
        final live = _session;
        if (live != null &&
            status != 'Paused' &&
            (fileEnded || stalled || status != 'Playing')) {
          _pausedAt = fileEnded && resumeAt > const Duration(seconds: 1)
              ? resumeAt - const Duration(seconds: 1)
              : resumeAt;
          var sought = await _seekLocal(live);
          if (!sought) {
            await live.callMethod(_playerInterface, 'Play', const []);
            await Future<void>.delayed(const Duration(milliseconds: 250));
            sought = await _seekLocal(live);
          }
          if (await _playbackStatus(live) != 'Playing') {
            await live.callMethod(_playerInterface, 'Play', const []);
          }
          final woke = await _untilPlaying(live);
          print(
            fileEnded
                ? 'gastube: background audio resume status=$woke '
                    'positionMs=${_pausedAt.inMilliseconds} '
                    'coverMs=${cover.inMilliseconds}'
                : 'gastube: background audio wake status=$woke '
                    'positionMs=${_pausedAt.inMilliseconds}',
          );
        }
        print(
          'gastube: background audio back '
          'positionMs=${resumeAt.inMilliseconds}',
        );
        final audioUrl = _player.backgroundAudioUrl;
        if (audioUrl != null) {
          if (_usingSlice && !_extendRunning && !_replacedByFull) {
            unawaited(_extendArmed(audioUrl, _sliceEpoch));
          }
          unawaited(_cacheAudio(audioUrl));
        }
      }
      return;
    }
    await _pauseHub();
    _pageAudio = false;
    _away = false;
    print('gastube: mediahub back positionMs=${resumeAt.inMilliseconds}');
    try {
      await _resumeInApp(resumeAt, play: !stayPaused);
    } catch (error) {
      print('gastube: mediahub resume failed error=$error');
    }
    final url = _player.backgroundAudioUrl;
    if (url != null) unawaited(_cacheAudio(url));
  }

  Future<void> _open(String url) async {
    _ready = false;
    _openedUrl = null;
    await _destroySession();
    final client = _client ?? DBusClient.session();
    _client = client;
    final service = DBusRemoteObject(
      client,
      name: _serviceName,
      path: DBusObjectPath(_servicePath),
    );
    final created = await service.callMethod(
      _serviceName,
      'CreateSession',
      const [],
      replySignature: DBusSignature('os'),
    );
    final path = created.returnValues[0].asObjectPath();
    _uuid = created.returnValues[1].asString();
    final session = DBusRemoteObject(
      client,
      name: _serviceName,
      path: path,
    );
    _session = session;
    print('gastube: mediahub session path=$path uuid=$_uuid');
    await _rememberSession(_uuid, path.value);
    final headerMap = url.startsWith('file:')
        ? const <String, String>{}
        : _player.backgroundAudioHeaders;
    final headers = DBusDict(
      DBusSignature('s'),
      DBusSignature('s'),
      headerMap.map(
        (key, value) => MapEntry(DBusString(key), DBusString(value)),
      ),
    );
    final opened = await session.callMethod(
      _playerInterface,
      'OpenUriExtended',
      [DBusString(url), headers],
      replySignature: DBusSignature('b'),
    );
    final ok = opened.returnValues.first.asBoolean();
    _openedUrl = url;
    _ready = ok;
    final parsed = Uri.tryParse(url);
    final host = parsed == null
        ? 'unknown'
        : parsed.scheme == 'file'
            ? 'local'
            : (parsed.host.isEmpty ? 'unknown' : parsed.host);
    print('gastube: mediahub open ok=$ok host=$host');
  }

  /// The hardware decoder stays stuck after Lomiri stops the process, and a
  /// keyframe seek lands on the position from before the handoff. Reload the
  /// decoder and seek exactly. If the position falls back, pause and play,
  /// then seek once more.
  Future<void> _resumeInApp(Duration resumeAt, {required bool play}) async {
    final player = _player.player;
    await _reloadVideo(player);
    await _seekExact(player, resumeAt);
    if (!play) {
      print(
        'gastube: mediahub resume paused positionMs=${resumeAt.inMilliseconds}',
      );
      return;
    }
    await player.play();
    final landed = await _settledPosition(player, resumeAt);
    if ((landed - resumeAt).inMilliseconds.abs() <= 1500) {
      print(
        'gastube: mediahub resume positionMs=${landed.inMilliseconds}',
      );
      return;
    }
    print(
      'gastube: mediahub resume retry positionMs=${landed.inMilliseconds}',
    );
    await player.pause();
    await player.play();
    await _seekExact(player, resumeAt);
    final again = await _settledPosition(player, resumeAt);
    print('gastube: mediahub resume positionMs=${again.inMilliseconds}');
  }

  Future<void> _reloadVideo(Player player) async {
    try {
      await (player.platform as dynamic).command(['video-reload']);
    } catch (error) {
      print('gastube: mediahub video-reload failed error=$error');
    }
  }

  Future<void> _seekExact(Player player, Duration position) async {
    if (position <= Duration.zero) return;
    await (player.platform as dynamic).command([
      'seek',
      (position.inMilliseconds / 1000).toStringAsFixed(4),
      'absolute+exact',
    ]);
  }

  Future<Duration> _settledPosition(Player player, Duration target) async {
    var position = player.state.position;
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 75));
      position = player.state.position;
      if ((position - target).inMilliseconds.abs() <= 1500) return position;
    }
    return position;
  }

  /// Seek once the local file has a duration. Returns false when the seek
  /// stops playback, so the caller can fall back to the network URL.
  Future<bool> _seekLocal(DBusRemoteObject session) async {
    final targetUs = _pausedAt.inMicroseconds;
    if (targetUs <= 0) return true;
    for (var attempt = 0; attempt < 8; attempt++) {
      int duration = -1;
      try {
        duration = await _intProperty(session, 'Duration');
      } catch (error) {
        print('gastube: mediahub duration failed error=$error');
        return false;
      }
      final durationUs = duration > targetUs * 50 ? duration ~/ 1000 : duration;
      if (durationUs > targetUs) {
        try {
          await session.callMethod(
            _playerInterface,
            'Seek',
            [DBusUint64(targetUs)],
          );
        } catch (error) {
          print('gastube: mediahub seek failed error=$error');
          return false;
        }
        print('gastube: mediahub seek us=$targetUs durationUs=$durationUs');
        final status = await _playbackStatus(session);
        return status != 'Stopped';
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    print('gastube: mediahub seek skipped reason=duration');
    return false;
  }

  String? _readyLocal(String url) {
    if (_cachedUrl != url || _cachedFile == null) return null;
    final file = File(_cachedFile!);
    if (!file.existsSync() || file.lengthSync() <= 0) return null;
    return file.path;
  }

  /// A download that lost its connection still has complete DASH fragments on
  /// disk. Copy those and seek inside them when they already cover the
  /// handoff position.
  String? _snapshotLocal(String url, Duration position) {
    try {
      final partial = File('${_cachePath(url)}.partial');
      if (!partial.existsSync()) return null;
      final length = partial.lengthSync();
      final end = _lastCompleteAtom(partial, length);
      final needed = _bytesForPosition(partial, length, url, position);
      if (needed == null || end < needed) {
        print('gastube: mediahub local short have=$end need=$needed');
        return null;
      }
      final play = File('${_cachePath(url)}.play');
      final input = partial.openSync();
      final output = play.openSync(mode: FileMode.write);
      var left = end;
      while (left > 0) {
        final n = left > 65536 ? 65536 : left;
        output.writeFromSync(input.readSync(n));
        left -= n;
      }
      input.closeSync();
      output.closeSync();
      print('gastube: mediahub local snapshot bytes=$end');
      return play.path;
    } catch (error) {
      print('gastube: mediahub local snapshot failed error=$error');
      return null;
    }
  }

  int? _bytesForPosition(
    File file,
    int length,
    String url,
    Duration position,
  ) {
    final indexed = _indexedFragment(file, length, position);
    if (indexed != null) return indexed.end;
    final query = Uri.tryParse(url)?.queryParameters;
    final clen = int.tryParse(query?['clen'] ?? '') ?? 0;
    final dur = double.tryParse(query?['dur'] ?? '') ?? 0;
    if (clen <= 0 || dur <= 0) return null;
    final fraction = position.inMilliseconds / (dur * 1000);
    if (fraction <= 0) return 1;
    return (clen * fraction).ceil();
  }

  /// DASH fragment that contains [position], counted in the original file.
  _IndexedFragment? _indexedFragment(
    File file,
    int length,
    Duration position, {
    int extraUs = 60000000,
  }) {
    final handle = file.openSync();
    try {
      var offset = 0;
      final header = Uint8List(8);
      while (offset + 8 <= length && offset < 1024 * 1024) {
        handle.setPositionSync(offset);
        if (handle.readIntoSync(header) < 8) return null;
        var size = _be32(header);
        final type = String.fromCharCodes(header.sublist(4));
        if (size == 1) {
          if (offset + 16 > length) return null;
          if (handle.readIntoSync(header) < 8) return null;
          size = _be64(header);
        } else if (size < 8) {
          return null;
        }
        if (offset + size > length) return null;
        if (type == 'sidx') {
          final body = Uint8List(size - 8);
          handle.setPositionSync(offset + 8);
          if (handle.readIntoSync(body) < body.length) return null;
          return _fragmentInSidx(
            body,
            offset,
            offset + size,
            position,
            extraUs: extraUs,
          );
        }
        offset += size;
      }
      return null;
    } finally {
      handle.closeSync();
    }
  }

  _IndexedFragment? _fragmentInSidx(
    Uint8List body,
    int sidxOffset,
    int sidxEnd,
    Duration position, {
    int extraUs = 60000000,
  }) {
    if (body.length < 20) return null;
    final version = body[0];
    var cursor = 4;
    cursor += 4;
    final timescale = _be32At(body, cursor);
    cursor += 4;
    if (timescale <= 0) return null;
    int firstOffset;
    if (version == 0) {
      cursor += 4;
      firstOffset = _be32At(body, cursor);
      cursor += 4;
    } else if (body.length >= cursor + 16) {
      cursor += 8;
      firstOffset = _be64At(body, cursor);
      cursor += 8;
    } else {
      return null;
    }
    if (cursor + 4 > body.length) return null;
    final count = _be16At(body, cursor + 2);
    cursor += 4;
    var byte = sidxEnd + firstOffset;
    var timeUs = 0;
    final targetUs = position.inMicroseconds;
    var chosenStart = -1;
    var chosenEnd = -1;
    var chosenStartUs = 0;
    var chosenEndUs = 0;
    for (var i = 0; i < count; i++) {
      if (cursor + 12 > body.length) return null;
      final size = _be32At(body, cursor) & 0x7fffffff;
      cursor += 4;
      final duration = _be32At(body, cursor);
      cursor += 8;
      final start = byte;
      final startUs = timeUs;
      byte += size;
      timeUs += (duration * 1000000) ~/ timescale;
      if (chosenStart < 0 && targetUs < timeUs) {
        chosenStart = start;
        chosenStartUs = startUs;
      }
      if (chosenStart < 0) continue;
      chosenEnd = byte;
      chosenEndUs = timeUs;
      // extraUs == 0 keeps only the fragment under the playhead. A lock cannot
      // wait for the following minute to download.
      if (extraUs <= 0 || timeUs - targetUs >= extraUs) break;
    }
    if (chosenStart < 0 || chosenEnd <= chosenStart) return null;
    return _IndexedFragment(
      start: chosenStart,
      end: chosenEnd,
      startUs: chosenStartUs,
      endUs: chosenEndUs,
      sidxOffset: sidxOffset,
    );
  }

  int _be32At(Uint8List bytes, int offset) =>
      _be32(bytes.sublist(offset, offset + 4));

  int _be64At(Uint8List bytes, int offset) =>
      _be64(bytes.sublist(offset, offset + 8));

  int _be16At(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  int _lastCompleteAtom(File file, int length) {
    final handle = file.openSync();
    try {
      var offset = 0;
      var last = 0;
      final header = Uint8List(8);
      while (offset + 8 <= length) {
        handle.setPositionSync(offset);
        if (handle.readIntoSync(header) < 8) break;
        var size = _be32(header);
        if (size == 1) {
          if (offset + 16 > length) break;
          if (handle.readIntoSync(header) < 8) break;
          size = _be64(header);
        } else if (size < 8) {
          break;
        }
        if (offset + size > length) break;
        last = offset + size;
        offset = last;
      }
      return last;
    } finally {
      handle.closeSync();
    }
  }

  int _be32(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  int _be64(List<int> bytes) {
    var value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
    }
    return value;
  }

  Future<void> _cacheAudio(String url) async {
    if (_cachedUrl == url && _readyLocal(url) != null) return;
    if (_downloadingUrl == url) return;
    _downloadingUrl = url;
    final path = _cachePath(url);
    final expected =
        int.tryParse(Uri.tryParse(url)?.queryParameters['clen'] ?? '') ?? -1;
    final existing = File(path);
    if (existing.existsSync() &&
        expected > 0 &&
        existing.lengthSync() == expected) {
      _cachedUrl = url;
      _cachedFile = path;
      if (_downloadingUrl == url) _downloadingUrl = null;
      print('gastube: mediahub cache ready bytes=$expected');
      return;
    }
    for (var attempt = 0; attempt < 8 && _downloadingUrl == url; attempt++) {
      _jumpTo = null;
      final bytes = await _downloadOnce(url, path, expected);
      if (_jumpTo != null) break;
      if (bytes == null) {
        if (_rejectedUrl == url) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        continue;
      }
      if (_downloadingUrl != url) return;
      if (existing.existsSync()) existing.deleteSync();
      await File('$path.partial').rename(path);
      _cachedUrl = url;
      _cachedFile = path;
      _downloadingUrl = null;
      print('gastube: mediahub cache ready bytes=$bytes');
      return;
    }
    if (_rejectedUrl == url) {
      if (_downloadingUrl == url) _downloadingUrl = null;
      return;
    }
    final jump = _jumpTo;
    if (jump != null && _downloadingUrl == url) {
      _jumpTo = null;
      await _followPlayhead(url, jump);
    }
    if (_downloadingUrl == url) await _keepNearPlayhead(url);
    if (_downloadingUrl == url) _downloadingUrl = null;
  }

  /// Returns the finished size, or null when this attempt stopped early.
  Future<int?> _downloadOnce(String url, String path, int expected) async {
    final partial = File('$path.partial');
    HttpClient? client;
    var bytes = 0;
    try {
      await partial.parent.create(recursive: true);
      final have = partial.existsSync() ? partial.lengthSync() : 0;
      bytes = have;
      print('gastube: mediahub cache resume bytes=$have');
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      for (final entry in _player.backgroundAudioHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (have > 0 && (expected <= 0 || have < expected)) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      }
      final response = await request.close();
      final append = response.statusCode == HttpStatus.partialContent;
      if (response.statusCode != HttpStatus.ok && !append) {
        print('gastube: mediahub cache status=${response.statusCode}');
        if (response.statusCode == HttpStatus.forbidden ||
            response.statusCode == HttpStatus.gone) {
          _rejectedUrl = url;
        }
        return null;
      }
      if (!append) bytes = 0;
      final sink = partial.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      var nextJumpCheck = bytes < 8192 ? 8192 : bytes + 65536;
      try {
        await for (final chunk in response) {
          if (_downloadingUrl != url) return null;
          sink.add(chunk);
          bytes += chunk.length;
          if (bytes < nextJumpCheck) continue;
          await sink.flush();
          nextJumpCheck = bytes + 65536;
          final jump = _jumpTarget(url, bytes);
          if (jump == null) continue;
          _jumpTo = jump;
          print('gastube: mediahub cache jump byte=$jump have=$bytes');
          return null;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      final headerLength = response.contentLength;
      final complete = (expected > 0 && bytes == expected) ||
          (!append && headerLength > 0 && bytes == headerLength);
      if (!complete || _downloadingUrl != url) {
        print('gastube: mediahub cache short bytes=$bytes');
        return null;
      }
      return bytes;
    } catch (error) {
      print(
        'gastube: mediahub cache failed error=${error.runtimeType} bytes=$bytes',
      );
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  String _backgroundAudioDirectory() {
    final cacheHome = Platform.environment['XDG_CACHE_HOME'];
    final home = Platform.environment['HOME'] ?? '';
    final base = (cacheHome != null && cacheHome.isNotEmpty)
        ? cacheHome
        : p.join(home, '.cache');
    return p.join(base, UbuntuTouch.clickPackage, 'background-audio');
  }

  List<File> _backgroundAudioFiles() {
    final dir = Directory(_backgroundAudioDirectory());
    if (!dir.existsSync()) return const [];
    final files = <File>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is File) files.add(entity);
    }
    return files;
  }

  /// Deletes the files that belonged to the playback that just ended.
  ///
  /// A later video may already be writing its own cache. Only the paths
  /// captured when that playback stopped are removed.
  void _removeSessionCache(List<File> files) {
    var removed = 0;
    var bytes = 0;
    for (final file in files) {
      if (!file.existsSync()) continue;
      final length = file.lengthSync();
      try {
        file.deleteSync();
      } catch (error) {
        print(
          'gastube: mediahub cache session failed '
          'file=${p.basename(file.path)} error=$error',
        );
        continue;
      }
      removed++;
      bytes += length;
    }
    if (removed > 0) {
      print('gastube: mediahub cache session removed=$removed bytes=$bytes');
    }
  }

  String _cachePath(String url) {
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) & 0x7fffffff;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return p.join(_backgroundAudioDirectory(), 'audio-$hash.m4a');
  }

  int? _jumpTarget(String url, int have) {
    final partial = File('${_cachePath(url)}.partial');
    if (!partial.existsSync()) return null;
    final length = partial.lengthSync();
    if (length < 32) return null;
    final frag = _indexedFragment(partial, length, _player.currentPosition);
    if (frag == null || frag.start <= have) return null;
    return frag.start;
  }

  Future<void> _followPlayhead(String url, int start) async {
    var at = start;
    while (_downloadingUrl == url) {
      final next = await _downloadAhead(url, at);
      if (next == null) return;
      at = next;
    }
  }

  /// The first jump can land on a resume position the user then leaves.
  /// Keep saving the fragment under the playhead while this video is open.
  Future<void> _keepNearPlayhead(String url) async {
    var tried = -1;
    while (_downloadingUrl == url) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_downloadingUrl != url) return;
      final partial = File('${_cachePath(url)}.partial');
      if (!partial.existsSync() || partial.lengthSync() < 32) continue;
      final frag = _indexedFragment(
        partial,
        partial.lengthSync(),
        _player.currentPosition,
        extraUs: 0,
      );
      if (frag == null || _aheadCovers(url, frag.start)) {
        tried = -1;
        continue;
      }
      if (frag.start == tried) continue;
      tried = frag.start;
      print('gastube: mediahub cache retarget byte=${frag.start}');
      await _followPlayhead(url, frag.start);
    }
  }

  bool _aheadCovers(String url, int byte) {
    final path = _cachePath(url);
    final file = File('$path.ahead');
    final marked = _readIntFile(File('$path.ahead.off'));
    if (marked == null || !file.existsSync()) return false;
    final usable = _lastCompleteAtom(file, file.lengthSync());
    return byte >= marked && byte < marked + usable;
  }

  /// Bytes from [start] through the end of the audio. Returns a later file
  /// offset when the playhead moves past what this range has stored.
  Future<int?> _downloadAhead(String url, int start) async {
    final path = _cachePath(url);
    final file = File('$path.ahead');
    final mark = File('$path.ahead.off');
    final marked = _readIntFile(mark);
    var rangeStart = start;
    var existing = 0;
    if (marked != null && file.existsSync()) {
      final end = marked + file.lengthSync();
      if (start >= marked && start <= end) {
        rangeStart = end;
        existing = file.lengthSync();
        start = marked;
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    }
    await mark.parent.create(recursive: true);
    await mark.writeAsString('$start');
    print('gastube: mediahub cache ahead byte=$start from=$rangeStart');
    final client = HttpClient();
    var bytes = existing;
    try {
      final request = await client.getUrl(Uri.parse(url));
      _setAudioHeaders(request);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-');
      final response = await request.close();
      final whole = response.statusCode == HttpStatus.ok && rangeStart == 0;
      if (response.statusCode != HttpStatus.partialContent && !whole) {
        print('gastube: mediahub cache ahead status=${response.statusCode}');
        return null;
      }
      final sink = file.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var nextCheck = bytes + 32768;
      try {
        await for (final chunk in response) {
          if (_downloadingUrl != url) return null;
          sink.add(chunk);
          bytes += chunk.length;
          if (bytes < nextCheck) continue;
          await sink.flush();
          nextCheck = bytes + 32768;
          final partial = File('$path.partial');
          if (!partial.existsSync()) continue;
          final frag = _indexedFragment(
            partial,
            partial.lengthSync(),
            _player.currentPosition,
          );
          if (frag != null &&
              (frag.start > start + bytes || frag.start < start)) {
            print('gastube: mediahub cache retarget byte=${frag.start}');
            return frag.start;
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      print('gastube: mediahub cache ahead ready bytes=$bytes');
      return null;
    } catch (error) {
      print(
        'gastube: mediahub cache ahead failed error=${error.runtimeType} bytes=$bytes',
      );
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// A local file whose samples start at the fragment covering [position].
  /// media-hub keeps those timestamps, so a seek still lands on [position].
  Future<String?> _sliceLocal(
    String url,
    Duration position, {
    bool fast = false,
  }) async {
    final path = _cachePath(url);
    final partial = File('$path.partial');
    if (!partial.existsSync()) {
      await _fillRange(url, 0, partial, 8192, extra: false);
    }
    if (!partial.existsSync() || partial.lengthSync() < 32) return null;
    final length = partial.lengthSync();
    final frag = _indexedFragment(partial, length, position, extraUs: 0);
    // Three minutes is enough to start. Anything already saved past that is
    // copied too, up to half an hour, so a long video is not cut at one
    // fragment or at sixty seconds.
    final near = _indexedFragment(partial, length, position, extraUs: 180000000) ??
        frag;
    final far =
        _indexedFragment(partial, length, position, extraUs: 1800000000) ??
            near;
    if (frag == null || near == null || far == null || frag.sidxOffset <= 0) {
      return null;
    }
    final ahead = File('$path.ahead');
    final aheadAt = _readIntFile(File('$path.ahead.off'));
    File? media;
    var mediaAt = 0;
    var usable = 0;
    if (aheadAt != null && ahead.existsSync() && aheadAt <= frag.start) {
      final aheadUsable = _lastCompleteAtom(ahead, ahead.lengthSync());
      if (aheadAt + aheadUsable >= frag.end) {
        media = ahead;
        mediaAt = aheadAt;
        usable = aheadUsable;
      }
    }
    if (media == null || mediaAt + usable < near.end) {
      final grab = File('$path.grab');
      final floor = frag.end - frag.start;
      final want = fast ? floor : far.end - frag.start;
      final got = await _fillRange(
        url,
        frag.start,
        grab,
        want,
        extra: false,
        floor: floor,
        maxWait: fast ? null : const Duration(milliseconds: 2500),
        cancelWhenDisarmed: fast,
      );
      final grabUsable =
          grab.existsSync() ? _lastCompleteAtom(grab, grab.lengthSync()) : 0;
      if (grabUsable > usable && got >= floor) {
        media = grab;
        mediaAt = frag.start;
        usable = grabUsable;
      } else if (media == null) {
        print('gastube: mediahub slice short bytes=$got');
        return null;
      }
    }
    final chosen = media;
    if (chosen == null) return null;
    final from = frag.start - mediaAt;
    final available = mediaAt + usable;
    final endByte = far.end < available ? far.end : available;
    if (from < 0 || endByte > available || endByte <= frag.start) return null;
    final count = endByte - frag.start;
    final play = File('$path.play');
    final header = partial.openSync();
    final output = play.openSync(mode: FileMode.write);
    try {
      output.writeFromSync(header.readSync(frag.sidxOffset));
      final input = chosen.openSync();
      try {
        if (from > 0) input.setPositionSync(from);
        var left = count;
        while (left > 0) {
          final n = left > 65536 ? 65536 : left;
          output.writeFromSync(input.readSync(n));
          left -= n;
        }
      } finally {
        input.closeSync();
      }
    } finally {
      header.closeSync();
      output.closeSync();
    }
    _sliceFrom = Duration(microseconds: frag.startUs);
    if (fast) {
      _sliceMediaStart = frag.start;
      _sliceSidxOffset = frag.sidxOffset;
      _sliceGrabBytes = count;
      _sliceUntilUs = frag.endUs;
    }
    print(
      'gastube: mediahub slice bytes=${play.lengthSync()} '
      'fromUs=${frag.startUs} coverBytes=$count',
    );
    return play.path;
  }

  /// Keeps fetching the rest of [url] from the fragment already playing and
  /// replaces the short file before it runs out.
  Future<void> _extendArmed(String url, int epoch, {int attempt = 0}) async {
    if (_extendRunning) return;
    _extendRunning = true;
    final mediaStart = _sliceMediaStart;
    final sidxOffset = _sliceSidxOffset;
    final grabBytes = _sliceGrabBytes;
    if (mediaStart == null || sidxOffset == null || grabBytes == null) {
      _extendRunning = false;
      return;
    }
    final path = _cachePath(url);
    final partial = File('$path.partial');
    final grab = File('$path.grab');
    if (!partial.existsSync() || !grab.existsSync()) {
      _extendRunning = false;
      return;
    }
    final more = File('$path.more');
    if (more.existsSync()) more.deleteSync();
    await more.parent.create(recursive: true);
    final offer = _ExtendOffer(
      epoch: epoch,
      path: path,
      partial: partial,
      sidxOffset: sidxOffset,
      grab: grab,
      grabBytes: grabBytes,
      more: more,
      mediaStart: mediaStart,
      openedUntil: _sliceUntilUs ?? 0,
    );
    _extendOffer = offer;
    final client = HttpClient();
    var bytes = 0;
    var failed = false;
    try {
      final sink = more.openWrite();
      try {
        // One long range is sent about as fast as playback. A bounded range
        // comes back in a burst. Keep asking until the open file can hold
        // about eight minutes past the playhead, which is what still plays
        // after the screen lock stops this process.
        while (epoch == _sliceEpoch &&
            _player.backgroundAudioArmed &&
            !_replacedByFull &&
            !offer.finished) {
          final rangeStart = mediaStart + grabBytes + bytes;
          final heardUs = _heardUntil.inMicroseconds;
          final anchor =
              heardUs > offer.openedUntil ? heardUs : offer.openedUntil;
          final wantUs = anchor + 480000000;
          final indexed = partial.existsSync()
              ? _fileByteAtUs(partial, partial.lengthSync(), wantUs)
              : null;
          var rangeEnd = indexed ?? rangeStart + 768 * 1024;
          if (indexed != null && indexed <= rangeStart) {
            rangeEnd = rangeStart;
          }
          if (rangeEnd > rangeStart + 1536 * 1024) {
            rangeEnd = rangeStart + 1536 * 1024;
          }
          if (rangeEnd <= rangeStart) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (_coverRunningOut()) {
              _offerArmedExtension(offer, finished: false);
            }
            continue;
          }
          final request = await client.getUrl(Uri.parse(url));
          _setAudioHeaders(request);
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$rangeStart-${rangeEnd - 1}',
          );
          final response = await request.close();
          if (response.statusCode != HttpStatus.partialContent) {
            print(
              'gastube: background audio extend status=${response.statusCode}',
            );
            return;
          }
          final total = _contentRangeTotal(response.headers);
          var got = 0;
          await for (final chunk in response) {
            if (epoch != _sliceEpoch ||
                !_player.backgroundAudioArmed ||
                _replacedByFull) {
              return;
            }
            sink.add(chunk);
            got += chunk.length;
            bytes += chunk.length;
            if (got < 131072) continue;
            await sink.flush();
            offer.moreBytes = bytes;
            if (_coverRunningOut()) {
              _offerArmedExtension(offer, finished: false);
            }
          }
          await sink.flush();
          offer.moreBytes = bytes;
          if (total != null && rangeStart + got >= total) {
            offer.finished = true;
          }
          print('gastube: background audio chunk bytes=$bytes');
          _offerArmedExtension(offer, finished: offer.finished);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } catch (error) {
      failed = true;
      print(
        'gastube: background audio extend failed error=${error.runtimeType}',
      );
    } finally {
      _extendRunning = false;
      client.close(force: true);
    }
    if (!failed ||
        attempt >= 3 ||
        epoch != _sliceEpoch ||
        !_player.backgroundAudioArmed ||
        _replacedByFull) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await _extendArmed(url, epoch, attempt: attempt + 1);
  }

  void _offerArmedExtension(
    _ExtendOffer offer, {
    required bool finished,
    bool followUp = false,
  }) {
    if (offer.epoch != _sliceEpoch ||
        !_player.backgroundAudioArmed ||
        _replacedByFull) {
      return;
    }
    if (finished) offer.finished = true;
    final moreBytes = offer.moreBytes;
    if (moreBytes <= 0 || !offer.partial.existsSync()) return;
    if (_extendPending) {
      offer.refresh = true;
      return;
    }
    final covered = _coveredMedia(
      offer.partial,
      offer.partial.lengthSync(),
      offer.mediaStart,
      offer.grabBytes + moreBytes,
    );
    if (covered == null || covered.endUs <= offer.openedUntil) return;
    final moreCopy = covered.mediaBytes - offer.grabBytes;
    if (moreCopy <= 0) return;
    // The first extra file has to arrive before the one fragment ends.
    // Later files wait until playback is close to that end, and they include
    // every complete fragment already downloaded. A follow-up after the
    // first swap takes the bytes that arrived while that swap was opening.
    final rescue = !_didExtend;
    final urgent = _coverRunningOut();
    final gained = covered.endUs - offer.openedUntil;
    final heardUs = _heardUntil.inMicroseconds;
    final openAhead = (_sliceUntilUs ?? offer.openedUntil) - heardUs;
    // The file media-hub has open is the only audio that survives a lock.
    // Top it up while the screen is on, once a few more minutes are on disk.
    final roomToFill = openAhead < 180000000;
    final extendNow = finished || (followUp && urgent);
    if (!extendNow && rescue && !urgent && gained < 45000000) return;
    if (!extendNow && rescue && urgent && gained < 8000000) return;
    if (!extendNow && !rescue && !urgent && !roomToFill) return;
    if (!extendNow && !rescue && !urgent && gained < 90000000) return;
    if (!extendNow && !rescue && urgent && gained < 8000000) return;
    final endUs = covered.endUs;
    final gap = !urgent && !rescue
        ? const Duration(seconds: 20)
        : const Duration(seconds: 2);
    if (!extendNow &&
        _extendChecked.millisecondsSinceEpoch != 0 &&
        DateTime.now().difference(_extendChecked) < gap) {
      return;
    }
    offer.refresh = false;
    _extendChecked = DateTime.now();
    _extendPending = true;
    final composed = _composeArmed(
      partial: offer.partial,
      sidxOffset: offer.sidxOffset,
      grab: offer.grab,
      grabBytes: offer.grabBytes,
      more: offer.more,
      moreBytes: moreCopy,
      path: offer.path,
      endUs: endUs,
    );
    if (composed == null) {
      _extendPending = false;
      return;
    }
    unawaited(_enqueue(() async {
      var played = false;
      try {
        played = await _swapArmed(composed, offer.epoch, endUs);
        if (played) offer.openedUntil = endUs;
      } finally {
        _extendPending = false;
        final again = played && offer.refresh && !offer.followed;
        offer.refresh = false;
        if (again &&
            offer.epoch == _sliceEpoch &&
            _player.backgroundAudioArmed &&
            !_replacedByFull) {
          offer.followed = true;
          print('gastube: background audio extend again');
          _offerArmedExtension(
            offer,
            finished: offer.finished,
            followUp: true,
          );
        } else if (!played) {
          _extendChecked = DateTime.now();
        }
      }
    }));
  }

  String? _composeArmed({
    required File partial,
    required int sidxOffset,
    required File grab,
    required int grabBytes,
    required File more,
    required int moreBytes,
    required String path,
    required int endUs,
  }) {
    try {
      final dest = File('$path.ext-$endUs');
      final header = partial.openSync();
      final output = dest.openSync(mode: FileMode.write);
      try {
        output.writeFromSync(header.readSync(sidxOffset));
        _copyInto(output, grab, grabBytes);
        _copyInto(output, more, moreBytes);
      } finally {
        header.closeSync();
        output.closeSync();
      }
      return dest.path;
    } catch (error) {
      print('gastube: background audio compose failed error=$error');
      return null;
    }
  }

  void _copyInto(RandomAccessFile output, File input, int count) {
    final handle = input.openSync();
    try {
      var left = count;
      while (left > 0) {
        final n = left > 65536 ? 65536 : left;
        output.writeFromSync(handle.readSync(n));
        left -= n;
      }
    } finally {
      handle.closeSync();
    }
  }

  Future<bool> _swapArmed(
    String path,
    int epoch,
    int coverUs, {
    bool wholeFile = false,
  }) async {
    if (epoch != _sliceEpoch || !_player.backgroundAudioArmed) return false;
    if (!_pageAudio && !_away) return false;
    final hub = await _hubPosition();
    if (hub > _pausedAt) _pausedAt = hub;
    if (hub > _heardUntil) _heardUntil = hub;
    if (!wholeFile && coverUs <= _pausedAt.inMicroseconds + 500000) return false;
    await _open(Uri.file(path).toString());
    final session = _session;
    if (session == null || !_ready) {
      print('gastube: background audio extend open failed');
      return false;
    }
    final sought = await _seekLocal(session);
    if (!sought) {
      print('gastube: background audio extend seek failed');
      return false;
    }
    var status = await _playbackStatus(session);
    for (var attempt = 0; attempt < 4 && status != 'Playing'; attempt++) {
      await session.callMethod(_playerInterface, 'Play', const []);
      status = await _untilPlaying(session, attempts: 8);
    }
    if (status == 'Playing') {
      if (!wholeFile) _sliceUntilUs = coverUs;
      _didExtend = true;
      _dropOtherExtensions(path);
    }
    print(
      wholeFile
          ? 'gastube: background audio full status=$status '
              'positionMs=${_pausedAt.inMilliseconds}'
          : 'gastube: background audio extend status=$status '
              'positionMs=${_pausedAt.inMilliseconds} coverMs=${coverUs ~/ 1000}',
    );
    return status == 'Playing';
  }

  /// One extend swap replaces the file media-hub has open. The older
  /// `.ext-` copies are not played again, so they do not stay on disk.
  void _dropOtherExtensions(String opened) {
    final name = p.basename(opened);
    final mark = name.indexOf('.ext-');
    final stem = mark > 0 ? name.substring(0, mark) : name;
    final dir = Directory(p.dirname(opened));
    if (!dir.existsSync()) return;
    var removed = 0;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (base == name || !base.startsWith('$stem.ext-')) continue;
      try {
        entity.deleteSync();
        removed++;
      } catch (error) {
        print('gastube: background audio ext drop failed error=$error');
      }
    }
    if (removed > 0) {
      print('gastube: background audio ext drop removed=$removed');
    }
  }

  bool _coverRunningOut() {
    final until = _sliceUntilUs;
    if (until == null || until <= 0) return false;
    final heard = _heardUntil.inMicroseconds;
    if (heard <= 0) return false;
    return until - heard <= 12000000;
  }

  /// Remembers how far the page audio actually reached, and switches to the
  /// finished download once that file is on disk.
  Future<void> _followArmedClock(String url, int epoch) async {
    while (epoch == _sliceEpoch && _player.backgroundAudioArmed) {
      await Future.delayed(const Duration(seconds: 2));
      if (epoch != _sliceEpoch || !_player.backgroundAudioArmed) return;
      await _enqueue(() => _noteArmedClock(url, epoch));
    }
  }

  Future<void> _noteArmedClock(String url, int epoch) async {
    if (epoch != _sliceEpoch || !_player.backgroundAudioArmed) return;
    if (!_pageAudio && !_away) return;
    final session = _session;
    var at = await _hubPosition();
    final untilUs = _sliceUntilUs;
    if (session != null && untilUs != null) {
      final status = await _playbackStatus(session);
      if (status == 'Stopped') {
        final until = Duration(microseconds: untilUs);
        if (until > at && until - at < const Duration(seconds: 20)) {
          at = until;
        }
      }
    }
    if (at > _heardUntil) _heardUntil = at;
    if (at > _pausedAt) _pausedAt = at;
    final bookmark = _player.systemPlayerHandoffUrl;
    if (bookmark != null && _heardUntil > Duration.zero) {
      await noteSystemPlayerBookmark(bookmark, _heardUntil);
      _player.updateSystemPlayerHandoffPosition(_heardUntil);
      print(
        'gastube: background audio heard positionMs=${_heardUntil.inMilliseconds}',
      );
    }
    final offer = _extendOffer;
    if (offer != null &&
        !_extendPending &&
        !_replacedByFull &&
        _usingSlice &&
        (offer.finished || _coverRunningOut())) {
      _offerArmedExtension(offer, finished: offer.finished);
    }
    if (_replacedByFull || !_usingSlice) return;
    final ready = _readyLocal(url);
    if (ready == null) return;
    if (_heardUntil > _pausedAt) _pausedAt = _heardUntil;
    final played = await _swapArmed(ready, epoch, 0, wholeFile: true);
    if (!played) return;
    _replacedByFull = true;
    _usingSlice = false;
    _sliceUntilUs = null;
  }

  _CoveredMedia? _coveredMedia(
    File partial,
    int length,
    int mediaStart,
    int mediaBytes,
  ) {
    if (mediaBytes <= 0 || length < 32) return null;
    final handle = partial.openSync();
    try {
      var offset = 0;
      final header = Uint8List(8);
      while (offset + 8 <= length && offset < 1024 * 1024) {
        handle.setPositionSync(offset);
        if (handle.readIntoSync(header) < 8) return null;
        var size = _be32(header);
        final type = String.fromCharCodes(header.sublist(4));
        if (size == 1) {
          if (offset + 16 > length) return null;
          if (handle.readIntoSync(header) < 8) return null;
          size = _be64(header);
        } else if (size < 8) {
          return null;
        }
        if (offset + size > length) return null;
        if (type == 'sidx') {
          final body = Uint8List(size - 8);
          handle.setPositionSync(offset + 8);
          if (handle.readIntoSync(body) < body.length) return null;
          return _coveredInSidx(body, offset + size, mediaStart, mediaBytes);
        }
        offset += size;
      }
      return null;
    } finally {
      handle.closeSync();
    }
  }

  _CoveredMedia? _coveredInSidx(
    Uint8List body,
    int sidxEnd,
    int mediaStart,
    int mediaBytes,
  ) {
    if (body.length < 20) return null;
    final version = body[0];
    var cursor = 4;
    cursor += 4;
    final timescale = _be32At(body, cursor);
    cursor += 4;
    if (timescale <= 0) return null;
    int firstOffset;
    if (version == 0) {
      cursor += 4;
      firstOffset = _be32At(body, cursor);
      cursor += 4;
    } else if (body.length >= cursor + 16) {
      cursor += 8;
      firstOffset = _be64At(body, cursor);
      cursor += 8;
    } else {
      return null;
    }
    if (cursor + 4 > body.length) return null;
    final count = _be16At(body, cursor + 2);
    cursor += 4;
    var byte = sidxEnd + firstOffset;
    var timeUs = 0;
    final limit = mediaStart + mediaBytes;
    int? coveredUs;
    var coveredBytes = 0;
    for (var i = 0; i < count; i++) {
      if (cursor + 12 > body.length) break;
      final size = _be32At(body, cursor) & 0x7fffffff;
      cursor += 4;
      final duration = _be32At(body, cursor);
      cursor += 8;
      final start = byte;
      byte += size;
      timeUs += (duration * 1000000) ~/ timescale;
      if (byte > limit) break;
      if (start >= mediaStart) {
        coveredUs = timeUs;
        coveredBytes = byte - mediaStart;
      }
    }
    final endUs = coveredUs;
    if (endUs == null || coveredBytes <= 0) return null;
    return _CoveredMedia(endUs, coveredBytes);
  }

  /// Absolute file offset where [targetUs] has finished, from the sidx.
  int? _fileByteAtUs(File partial, int length, int targetUs) {
    if (targetUs <= 0 || length < 32) return null;
    final handle = partial.openSync();
    try {
      var offset = 0;
      final header = Uint8List(8);
      while (offset + 8 <= length && offset < 1024 * 1024) {
        handle.setPositionSync(offset);
        if (handle.readIntoSync(header) < 8) return null;
        var size = _be32(header);
        final type = String.fromCharCodes(header.sublist(4));
        if (size == 1) {
          if (offset + 16 > length) return null;
          if (handle.readIntoSync(header) < 8) return null;
          size = _be64(header);
        } else if (size < 8) {
          return null;
        }
        if (offset + size > length) return null;
        if (type == 'sidx') {
          final body = Uint8List(size - 8);
          handle.setPositionSync(offset + 8);
          if (handle.readIntoSync(body) < body.length) return null;
          return _byteAtUsInSidx(body, offset + size, targetUs);
        }
        offset += size;
      }
      return null;
    } finally {
      handle.closeSync();
    }
  }

  int? _byteAtUsInSidx(Uint8List body, int sidxEnd, int targetUs) {
    if (body.length < 20) return null;
    final version = body[0];
    var cursor = 4;
    cursor += 4;
    final timescale = _be32At(body, cursor);
    cursor += 4;
    if (timescale <= 0) return null;
    int firstOffset;
    if (version == 0) {
      cursor += 4;
      firstOffset = _be32At(body, cursor);
      cursor += 4;
    } else if (body.length >= cursor + 16) {
      cursor += 8;
      firstOffset = _be64At(body, cursor);
      cursor += 8;
    } else {
      return null;
    }
    if (cursor + 4 > body.length) return null;
    final count = _be16At(body, cursor + 2);
    cursor += 4;
    var byte = sidxEnd + firstOffset;
    var timeUs = 0;
    var last = byte;
    for (var i = 0; i < count; i++) {
      if (cursor + 12 > body.length) break;
      final size = _be32At(body, cursor) & 0x7fffffff;
      cursor += 4;
      final duration = _be32At(body, cursor);
      cursor += 8;
      byte += size;
      timeUs += (duration * 1000000) ~/ timescale;
      last = byte;
      if (timeUs >= targetUs) return byte;
    }
    return last;
  }

  int? _contentRangeTotal(HttpHeaders headers) {
    final value = headers.value(HttpHeaders.contentRangeHeader);
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    if (slash < 0 || slash + 1 >= value.length) return null;
    if (value.substring(slash + 1) == '*') return null;
    return int.tryParse(value.substring(slash + 1));
  }

  /// Downloads [minimum] bytes starting at [start], then a little more when
  /// [extra] is set, so playback has more than the current fragment.
  Future<int> _fillRange(
    String url,
    int start,
    File dest,
    int minimum, {
    bool extra = true,
    int? floor,
    Duration? maxWait,
    bool cancelWhenDisarmed = false,
  }) async {
    if (dest.existsSync()) dest.deleteSync();
    await dest.parent.create(recursive: true);
    final client = HttpClient();
    var bytes = 0;
    try {
      final request = await client.getUrl(Uri.parse(url));
      _setAudioHeaders(request);
      if (start > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-');
      }
      final response = await request.close();
      final ranged = response.statusCode == HttpStatus.partialContent;
      final whole = start == 0 && response.statusCode == HttpStatus.ok;
      if (!ranged && !whole) {
        print('gastube: mediahub slice status=${response.statusCode}');
        return 0;
      }
      final sink = dest.openWrite();
      final clock = Stopwatch()..start();
      var coveredAt = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          bytes += chunk.length;
          if (cancelWhenDisarmed && !_player.backgroundAudioArmed) break;
          if (cancelWhenDisarmed &&
              clock.elapsed >= const Duration(seconds: 8) &&
              bytes < (floor ?? minimum)) {
            break;
          }
          final haveFloor = floor == null || bytes >= floor;
          if (haveFloor && bytes >= minimum) break;
          if (maxWait != null &&
              haveFloor &&
              clock.elapsed >= maxWait) {
            break;
          }
          if (maxWait != null && clock.elapsed >= const Duration(seconds: 6)) {
            break;
          }
          if (maxWait != null || bytes < minimum) continue;
          if (!extra) break;
          if (coveredAt == 0) coveredAt = clock.elapsedMilliseconds;
          if (clock.elapsedMilliseconds - coveredAt >= 1200) break;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return bytes;
    } catch (error) {
      print(
        'gastube: mediahub slice failed error=${error.runtimeType} bytes=$bytes',
      );
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  void _setAudioHeaders(HttpClientRequest request) {
    for (final entry in _player.backgroundAudioHeaders.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }

  int? _readIntFile(File file) {
    if (!file.existsSync()) return null;
    return int.tryParse(file.readAsStringSync().trim());
  }

  Future<void> _pauseHub() async {
    final session = _session;
    if (session == null) return;
    try {
      await session.callMethod(_playerInterface, 'Pause', const []);
      print('gastube: mediahub pause');
    } catch (error) {
      print('gastube: mediahub pause failed error=$error');
    }
  }

  Future<void> _dropSession() async {
    await _destroySession();
    await _closeClient();
    _away = false;
    _pageAudio = false;
  }

  Future<Duration> _hubPosition() async {
    _hubKnown = false;
    final session = _session;
    if (session == null) return _pausedAt;
    try {
      final position = await _intProperty(session, 'Position');
      final duration = await _intProperty(session, 'Duration');
      if (position < 0) return _pausedAt;
      final localUs = _player.totalDuration.inMicroseconds;
      // media-hub reports nanoseconds. Without a local duration the old check
      // left the raw value, and a cleared player then resumed hours ahead.
      const dayUs = 24 * 60 * 60 * 1000000;
      final nanoseconds = duration > dayUs ||
          (localUs > 0 && duration > localUs * 50) ||
          (localUs > 0 && position > localUs * 50) ||
          (localUs <= 0 && duration >= 1000000000);
      final microseconds = nanoseconds ? position ~/ 1000 : position;
      _hubKnown = true;
      print(
        'gastube: mediahub position raw=$position duration=$duration us=$microseconds',
      );
      return Duration(microseconds: microseconds);
    } catch (error) {
      print('gastube: mediahub position failed error=$error');
      return _pausedAt;
    }
  }

  Future<String?> _untilPlaying(
    DBusRemoteObject session, {
    int attempts = 5,
  }) async {
    String? status;
    for (var attempt = 0; attempt < attempts; attempt++) {
      status = await _playbackStatus(session);
      if (status == 'Playing') return status;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return status;
  }

  Future<String?> _playbackStatus(DBusRemoteObject session) async {
    try {
      final reply = await session.callMethod(
        'org.freedesktop.DBus.Properties',
        'Get',
        [DBusString(_playerInterface), DBusString('PlaybackStatus')],
        replySignature: DBusSignature('v'),
      );
      final native = reply.returnValues.first.asVariant().toNative();
      if (native is String) return native;
    } catch (error) {
      print('gastube: mediahub status failed error=$error');
    }
    return null;
  }

  Future<void> _rememberSession(String? uuid, [String? path]) async {
    final note = (uuid == null || uuid.isEmpty) ? '' : '$uuid\n${path ?? ''}';
    try {
      await _sessionChannel.invokeMethod<void>('mediaHubSession', note);
    } catch (error) {
      print('gastube: mediahub session note failed error=$error');
    }
  }

  Future<int> _intProperty(DBusRemoteObject session, String name) async {
    final reply = await session.callMethod(
      'org.freedesktop.DBus.Properties',
      'Get',
      [DBusString(_playerInterface), DBusString(name)],
      replySignature: DBusSignature('v'),
    );
    final native = reply.returnValues.first.asVariant().toNative();
    if (native is int) return native;
    return -1;
  }

  Future<void> _prepareNeighbors() async {
    final current = _indicatorVideoId ?? _player.currentVideoId;
    if (current == null || current.isEmpty) return;
    final queue = PlaybackQueue();
    final neighbors = [
      queue.previousAfter(current),
      queue.nextAfter(current),
    ];
    for (final video in neighbors) {
      if (video == null || video.id.isEmpty || video.id == current) continue;
      if (_trackFiles.containsKey(video.id)) continue;
      try {
        final info = await NewPipeChannel.getStreamInfoFast(video.id);
        final url = _neighborAudioUrl(info);
        if (url == null) continue;
        final file = await _cacheExtra(url);
        if (file == null) continue;
        _trackFiles[video.id] = file;
        print('gastube: mediahub neighbor ready id=${video.id}');
      } catch (error) {
        print('gastube: mediahub neighbor failed id=${video.id} error=$error');
      }
    }
    if (_away && _session != null) {
      unawaited(_enqueue(() => _attachIndicatorTracks(anchor: true)));
    }
  }

  String? _neighborAudioUrl(NewPipeWatchResp info) {
    final streams = info.audioStreams ?? const [];
    String? fallback;
    String? m4a;
    var m4aRate = -1;
    for (final stream in streams) {
      final url = stream.url;
      if (url == null || url.isEmpty || stream.initStart != null) continue;
      fallback ??= url;
      final mime = '${stream.mimeType} ${stream.format}'.toLowerCase();
      if (!mime.contains('mp4') && !mime.contains('m4a')) continue;
      final rate = stream.averageBitrate ?? 0;
      if (rate < m4aRate) continue;
      m4aRate = rate;
      m4a = url;
    }
    return m4a ?? fallback;
  }

  Future<String?> _cacheExtra(String url) async {
    final path = _cachePath(url);
    final expected =
        int.tryParse(Uri.tryParse(url)?.queryParameters['clen'] ?? '') ?? -1;
    final existing = File(path);
    if (existing.existsSync() &&
        expected > 0 &&
        existing.lengthSync() == expected) {
      return path;
    }
    if (!_extraDownloads.add(url)) return null;
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        final bytes = await _downloadOnce(url, path, expected);
        if (bytes == null) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }
        if (existing.existsSync()) existing.deleteSync();
        await File('$path.partial').rename(path);
        return path;
      }
      return null;
    } finally {
      _extraDownloads.remove(url);
    }
  }

  Future<void> _attachIndicatorTracks({bool anchor = false}) async {
    final session = _session;
    final client = _client;
    final currentId = _player.currentVideoId;
    if (session == null || client == null || currentId == null) return;
    final list = DBusRemoteObject(
      client,
      name: _serviceName,
      path: DBusObjectPath('${session.path.value}/TrackList'),
    );
    try {
      await _listenTracks(list);
      var ids = await _trackListIds(list);
      if (ids.isEmpty) return;
      await _mapTracks(list, ids, currentId);
      final currentTrack = _idFor(currentId);
      if (currentTrack == null) return;
      final anchorId = _indicatorVideoId ?? currentId;
      final anchorTrack = _idFor(anchorId) ?? currentTrack;
      final queue = PlaybackQueue();
      final previous = queue.previousAfter(anchorId);
      final next = queue.nextAfter(anchorId);
      if (previous != null &&
          _trackFiles.containsKey(previous.id) &&
          _idFor(previous.id) == null) {
        await _addTrack(list, _trackFiles[previous.id]!, anchorTrack);
      }
      if (next != null &&
          _trackFiles.containsKey(next.id) &&
          _idFor(next.id) == null) {
        await _addTrack(list, _trackFiles[next.id]!, _noTrack);
      }
      ids = await _trackListIds(list);
      await _mapTracks(list, ids, currentId);
      final previousReady = previous != null && _idFor(previous.id) != null;
      final stillOnOpened =
          _indicatorVideoId == null || _indicatorVideoId == currentId;
      if (anchor && previousReady && !_anchored && stillOnOpened) {
        final at = await _hubPosition();
        if (at > _pausedAt) _pausedAt = at;
        await list.callMethod(_trackInterface, 'GoTo', [DBusString(currentTrack)]);
        await _seekLocal(session);
        if (await _playbackStatus(session) != 'Playing') {
          await session.callMethod(_playerInterface, 'Play', const []);
        }
        _anchored = true;
      }
      print(
        'gastube: mediahub indicator '
        'previous=${previous != null && _idFor(previous.id) != null} '
        'next=${next != null && _idFor(next.id) != null}',
      );
    } catch (error) {
      print('gastube: mediahub indicator failed error=$error');
    }
  }

  Future<void> _listenTracks(DBusRemoteObject list) async {
    await _trackChanged?.cancel();
    _trackChanged = DBusRemoteObjectSignalStream(
      object: list,
      interface: _trackInterface,
      name: 'TrackChanged',
    ).listen((signal) {
      if (signal.values.isEmpty) return;
      final videoId = _trackIds[signal.values.first.asString()];
      if (videoId == null) return;
      _indicatorVideoId = videoId;
      print('gastube: mediahub indicator video=$videoId');
      if (_away) unawaited(_prepareNeighbors());
    });
  }

  Future<void> _addTrack(
    DBusRemoteObject list,
    String path,
    String after,
  ) async {
    await list.callMethod(
      _trackInterface,
      'AddTrack',
      [
        DBusString(Uri.file(path).toString()),
        DBusString(after),
        const DBusBoolean(false),
      ],
    );
  }

  Future<List<String>> _trackListIds(DBusRemoteObject list) async {
    final reply = await list.callMethod(
      'org.freedesktop.DBus.Properties',
      'Get',
      [const DBusString(_trackInterface), const DBusString('Tracks')],
      replySignature: DBusSignature('v'),
    );
    final native = reply.returnValues.first.asVariant().toNative();
    if (native is! List) return const [];
    return native.map((item) => '$item').toList();
  }

  Future<void> _mapTracks(
    DBusRemoteObject list,
    List<String> ids,
    String currentId,
  ) async {
    for (final id in ids) {
      if (_trackIds.containsKey(id)) continue;
      final reply = await list.callMethod(
        _trackInterface,
        'GetTracksUri',
        [DBusString(id)],
        replySignature: DBusSignature('s'),
      );
      final uri = reply.returnValues.first.asString();
      if (_sameResource(uri, _openedUrl ?? '')) {
        _trackIds[id] = currentId;
        continue;
      }
      for (final entry in _trackFiles.entries) {
        if (!_sameResource(uri, Uri.file(entry.value).toString())) continue;
        _trackIds[id] = entry.key;
        break;
      }
    }
  }

  String? _idFor(String videoId) {
    for (final entry in _trackIds.entries) {
      if (entry.value == videoId) return entry.key;
    }
    return null;
  }

  bool _sameResource(String left, String right) {
    if (left == right) return true;
    return _filePathOf(left) != null && _filePathOf(left) == _filePathOf(right);
  }

  String? _filePathOf(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.scheme == 'file') return parsed.toFilePath();
    if (uri.startsWith('/')) return uri;
    return null;
  }

  Future<void> _destroySession() async {
    await _trackChanged?.cancel();
    _trackChanged = null;
    _trackIds.clear();
    _anchored = false;
    final uuid = _uuid;
    final client = _client;
    _uuid = null;
    _session = null;
    _ready = false;
    await _rememberSession(null);
    if (client == null || uuid == null) return;
    try {
      final service = DBusRemoteObject(
        client,
        name: _serviceName,
        path: DBusObjectPath(_servicePath),
      );
      await service.callMethod(
        _serviceName,
        'DestroySession',
        [DBusString(uuid)],
      );
      print('gastube: mediahub destroy uuid=$uuid');
    } catch (error) {
      print('gastube: mediahub destroy failed error=$error');
    }
  }

  Future<void> _closeClient() async {
    final client = _client;
    _client = null;
    _openedUrl = null;
    if (client == null) return;
    try {
      await client.close();
    } catch (_) {}
  }
}

class _ExtendOffer {
  _ExtendOffer({
    required this.epoch,
    required this.path,
    required this.partial,
    required this.sidxOffset,
    required this.grab,
    required this.grabBytes,
    required this.more,
    required this.mediaStart,
    required this.openedUntil,
  });

  final int epoch;
  final String path;
  final File partial;
  final int sidxOffset;
  final File grab;
  final int grabBytes;
  final File more;
  final int mediaStart;
  int openedUntil;
  int moreBytes = 0;
  bool finished = false;
  bool refresh = false;
  bool followed = false;
}

class _CoveredMedia {
  const _CoveredMedia(this.endUs, this.mediaBytes);

  final int endUs;
  final int mediaBytes;
}

class _IndexedFragment {
  const _IndexedFragment({
    required this.start,
    required this.end,
    required this.startUs,
    required this.endUs,
    required this.sidxOffset,
  });

  final int start;
  final int end;
  final int startUs;
  final int endUs;
  final int sidxOffset;
}

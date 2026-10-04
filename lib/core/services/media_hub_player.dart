import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/services/mpris_player.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:path/path.dart' as p;

/// Plays one audio URL through Lomiri media-hub while this process is away.
///
/// The session is opened while the app is still in front, because leaving only
/// delivers [AppLifecycleState.inactive] and Lomiri then stops the process.
/// In-app playback stays on mpv with `ao=pulse` until that moment. Desktop
/// builds never call this bus.
class MediaHubPlayer {
  static final MediaHubPlayer instance = MediaHubPlayer._();

  MediaHubPlayer._();

  static const _serviceName = 'com.lomiri.MediaHub.Service';
  static const _servicePath = '/com/lomiri/MediaHub/Service';
  static const _playerInterface = 'org.mpris.MediaPlayer2.Player';
  static const _sessionChannel = MethodChannel('lol.alphaliu01.gastube/url');

  final GlobalPlayerController _player = GlobalPlayerController();
  DBusClient? _client;
  DBusRemoteObject? _session;
  String? _uuid;
  String? _openedUrl;
  bool _ready = false;
  bool _away = false;
  Duration _pausedAt = Duration.zero;
  Future<void> _queue = Future<void>.value();
  String? _cachedUrl;
  String? _cachedFile;
  String? _downloadingUrl;

  /// Open the current audio URL without playing it, and start saving a local
  /// copy. media-hub can seek a local file. Seeking the YouTube URL ends it.
  Future<void> prepare() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    final url = _player.backgroundAudioUrl;
    if (url != null) unawaited(_cacheAudio(url));
    return _enqueue(_prepare);
  }

  /// media-hub starts the sound, then local playback stops.
  Future<void> handoff() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(_handoff);
  }

  Future<void> takeBack() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(_takeBack);
  }

  Future<void> stop() {
    if (!UbuntuTouch.enabled) return Future<void>.value();
    return _enqueue(() => _dropSession(resume: false));
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final done = _queue.then((_) => action());
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<void> _prepare() async {
    if (_away) return;
    final url = _player.backgroundAudioUrl;
    if (url == null) return;
    if (_ready && _openedUrl == url) return;
    await _open(url);
  }

  Future<void> _handoff() async {
    if (_away) return;
    if (!_player.isPlaying) return;
    final url = _player.backgroundAudioUrl;
    if (url == null) {
      print('gastube: mediahub skip reason=no-audio-url');
      return;
    }
    _pausedAt = _player.currentPosition;
    _away = true;
    print(
      'gastube: mediahub handoff host=${Uri.tryParse(url)?.host ?? "unknown"} '
      'positionMs=${_pausedAt.inMilliseconds} ready=$_ready',
    );
    var playingOnHub = false;
    try {
      if (!_ready || _openedUrl != url || _session == null) {
        await _open(url);
      }
      final local = _readyLocal(url) ?? _snapshotLocal(url, _pausedAt);
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
      }
      var session = _session;
      if (session == null || !_ready) {
        throw StateError('open failed');
      }
      if (seekLocal) {
        final sought = await _seekLocal(session);
        if (!sought) {
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
      print('gastube: mediahub play');
      playingOnHub = true;
      await _player.pausePlayback();
      await MprisPlayer.instance.release();
    } catch (error) {
      print('gastube: mediahub failed error=$error');
      if (!playingOnHub) _away = false;
    }
  }

  Future<void> _takeBack() async {
    if (!_away) return;
    final hubAt = await _hubPosition();
    // A hub position behind the handoff point means playback restarted at
    // the beginning. Keep the in-app position in that case.
    final resumeAt = hubAt >= _pausedAt ? hubAt : _pausedAt;
    await _pauseHub();
    await MprisPlayer.instance.reclaim();
    _away = false;
    print('gastube: mediahub back positionMs=${resumeAt.inMilliseconds}');
    try {
      await _resumeInApp(resumeAt);
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
    await _rememberSession(_uuid);
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
  Future<void> _resumeInApp(Duration resumeAt) async {
    final player = _player.player;
    await _reloadVideo(player);
    await _seekExact(player, resumeAt);
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
    final indexed = _sidxByteEnd(file, length, position);
    if (indexed != null) return indexed;
    final query = Uri.tryParse(url)?.queryParameters;
    final clen = int.tryParse(query?['clen'] ?? '') ?? 0;
    final dur = double.tryParse(query?['dur'] ?? '') ?? 0;
    if (clen <= 0 || dur <= 0) return null;
    final fraction = position.inMilliseconds / (dur * 1000);
    if (fraction <= 0) return 1;
    return (clen * fraction).ceil();
  }

  /// End offset of the DASH fragment that contains [position].
  int? _sidxByteEnd(File file, int length, Duration position) {
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
          return _sidxCoveredEnd(body, offset + size, position);
        }
        offset += size;
      }
      return null;
    } finally {
      handle.closeSync();
    }
  }

  int? _sidxCoveredEnd(Uint8List body, int sidxEnd, Duration position) {
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
    for (var i = 0; i < count; i++) {
      if (cursor + 12 > body.length) return null;
      final size = _be32At(body, cursor) & 0x7fffffff;
      cursor += 4;
      final duration = _be32At(body, cursor);
      cursor += 8;
      byte += size;
      timeUs += (duration * 1000000) ~/ timescale;
      if (targetUs < timeUs) return byte;
    }
    return null;
  }

  int _be32At(Uint8List bytes, int offset) => _be32(bytes.sublist(offset, offset + 4));

  int _be64At(Uint8List bytes, int offset) => _be64(bytes.sublist(offset, offset + 8));

  int _be16At(Uint8List bytes, int offset) => (bytes[offset] << 8) | bytes[offset + 1];

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
      final bytes = await _downloadOnce(url, path, expected);
      if (bytes == null) {
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
        return null;
      }
      if (!append) bytes = 0;
      final sink = partial.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response) {
          if (_downloadingUrl != url) return null;
          sink.add(chunk);
          bytes += chunk.length;
          await sink.flush();
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

  String _cachePath(String url) {
    final cacheHome = Platform.environment['XDG_CACHE_HOME'];
    final home = Platform.environment['HOME'] ?? '';
    final base = (cacheHome != null && cacheHome.isNotEmpty)
        ? cacheHome
        : p.join(home, '.cache');
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) & 0x7fffffff;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return p.join(
      base,
      UbuntuTouch.clickPackage,
      'background-audio',
      'audio-$hash.m4a',
    );
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

  Future<void> _dropSession({required bool resume}) async {
    await _destroySession();
    await _closeClient();
    _away = false;
    if (resume) {
      await MprisPlayer.instance.reclaim();
    }
  }

  Future<Duration> _hubPosition() async {
    final session = _session;
    if (session == null) return _pausedAt;
    try {
      final position = await _intProperty(session, 'Position');
      final duration = await _intProperty(session, 'Duration');
      if (position < 0) return _pausedAt;
      final localUs = _player.totalDuration.inMicroseconds;
      final nanoseconds =
          (duration > 0 && localUs > 0 && duration > localUs * 50) ||
              (localUs > 0 && position > localUs * 50);
      final microseconds = nanoseconds ? position ~/ 1000 : position;
      print(
        'gastube: mediahub position raw=$position duration=$duration us=$microseconds',
      );
      return Duration(microseconds: microseconds);
    } catch (error) {
      print('gastube: mediahub position failed error=$error');
      return _pausedAt;
    }
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

  Future<void> _rememberSession(String? uuid) async {
    try {
      await _sessionChannel.invokeMethod<void>('mediaHubSession', uuid ?? '');
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

  Future<void> _destroySession() async {
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

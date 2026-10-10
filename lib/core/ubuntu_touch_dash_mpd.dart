import 'dart:io';
import 'dart:typed_data';

import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_stream.dart';
import 'package:path/path.dart' as p;

/// A video-only stream whose DASH index the system player can use.
///
/// H.264 is an mp4 `sidx`. VP9 is a WebM `Cues` list. Both are expanded
/// into one SegmentList and paired with the m4a track.
bool ubuntuTouchDashVideo(NewPipeVideoStream? stream) {
  if (stream == null || !stream.hasDashInfo) return false;
  final url = stream.url;
  if (url == null || url.isEmpty) return false;
  final mime = stream.mimeType ?? '';
  final codec = (stream.codec ?? '').toLowerCase();
  if (mime.startsWith('video/mp4')) {
    return codec.isEmpty || codec.startsWith('avc');
  }
  if (mime.startsWith('video/webm')) {
    return codec.startsWith('vp9') || codec.contains('vp09');
  }
  return false;
}

/// An m4a track with the same kind of index.
bool ubuntuTouchDashAudio(NewPipeAudioStream? stream) {
  if (stream == null || !stream.hasDashInfo) return false;
  final url = stream.url;
  if (url == null || url.isEmpty) return false;
  final mime = stream.mimeType ?? '';
  return mime.startsWith('audio/mp4');
}

/// Writes a static MPD for [video] and [audio] and returns its path.
///
/// GStreamer 1.16 on this phone drops the query string of a BaseURL and then
/// cannot open the googlevideo address. The same bytes play when each
/// segment's `media` and the initialization `sourceURL` are the absolute
/// address, including that query. The index is read here and expanded into
/// a SegmentList, because a SegmentBase index on that file never produced
/// a stream.
Future<String?> writeUbuntuTouchDashMpd({
  required String videoId,
  required NewPipeVideoStream video,
  required NewPipeAudioStream audio,
}) async {
  if (!ubuntuTouchDashVideo(video) || !ubuntuTouchDashAudio(audio)) {
    return null;
  }
  final videoIndex = await _fetchRange(
    video.url!,
    video.indexStart!,
    video.indexEnd!,
  );
  final audioIndex = await _fetchRange(
    audio.url!,
    audio.indexStart!,
    audio.indexEnd!,
  );
  final videoTrack = await _videoTrack(video, videoIndex);
  final audioSidx = audioIndex == null
      ? null
      : _parseSidx(audioIndex, audio.indexEnd!);
  if (videoTrack == null || audioSidx == null) {
    print(
      'gastube: dash index missing video=${videoTrack != null} '
      'audio=${audioSidx != null}',
    );
    return null;
  }
  final durationMs = video.approxDurationMs ?? audio.approxDurationMs ?? 0;
  final seconds = durationMs > 0 ? durationMs / 1000.0 : videoTrack.durationSeconds;
  final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" mediaPresentationDuration="PT${seconds.toStringAsFixed(3)}S" minBufferTime="PT2S" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011">
  <Period>
    <AdaptationSet mimeType="${videoTrack.mimeType}" contentType="video">
      <Representation id="v" bandwidth="${video.bitrate ?? 1}" width="${video.width ?? 0}" height="${video.height ?? 0}" codecs="${_xml(video.codec ?? 'avc1')}">
        ${_segmentList(video.url!, video.initStart!, video.initEnd!, videoTrack)}
      </Representation>
    </AdaptationSet>
    <AdaptationSet mimeType="audio/mp4" contentType="audio">
      <Representation id="a" bandwidth="${audio.bitrate ?? audio.averageBitrate ?? 1}" codecs="${_xml(audio.codec ?? 'mp4a.40.2')}" audioSamplingRate="${audio.sampleRate ?? 44100}">
        ${_segmentList(audio.url!, audio.initStart!, audio.initEnd!, audioSidx)}
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''';
  final root = await persistentAppDirectory();
  final dir = Directory(p.join(root.path, 'dash'));
  await dir.create(recursive: true);
  final safeId = videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  final file = File(p.join(dir.path, 'hd-$safeId.mpd'));
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(xml);
  await tmp.rename(file.path);
  print(
    'gastube: dash mpd height=${video.height} fps=${video.fps} '
    'codec=${video.codec} videoSegs=${videoTrack.segments.length} '
    'audioSegs=${audioSidx.segments.length}',
  );
  return file.path;
}

String _segmentList(String url, int initStart, int initEnd, _Sidx sidx) {
  final timeline = StringBuffer();
  final urls = StringBuffer();
  for (var i = 0; i < sidx.segments.length; i++) {
    final seg = sidx.segments[i];
    if (i == 0) {
      timeline.writeln('<S t="0" d="${seg.duration}"/>');
    } else {
      timeline.writeln('<S d="${seg.duration}"/>');
    }
    urls.writeln(
      '<SegmentURL media="${_xml(url)}" mediaRange="${seg.start}-${seg.end}"/>',
    );
  }
  return '''
<SegmentList timescale="${sidx.timescale}">
          <Initialization sourceURL="${_xml(url)}" range="$initStart-$initEnd"/>
          <SegmentTimeline>
            ${timeline.toString().trim()}
          </SegmentTimeline>
          ${urls.toString().trim()}
        </SegmentList>''';
}

String _xml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

Future<Uint8List?> _fetchRange(String url, int start, int end) async {
  if (end < start || end - start > 2 * 1024 * 1024) return null;
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 206 && response.statusCode != 200) {
      print('gastube: dash index status=${response.statusCode}');
      await response.drain<void>();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > 2 * 1024 * 1024) {
        await response.drain<void>();
        return null;
      }
    }
    final bytes = builder.takeBytes();
    if (response.statusCode == 200 && start > 0) {
      if (bytes.length < end + 1) return null;
      return Uint8List.sublistView(bytes, start, end + 1);
    }
    return bytes;
  } catch (error) {
    print('gastube: dash index failed type=${error.runtimeType}');
    return null;
  } finally {
    client.close(force: true);
  }
}

class _Seg {
  const _Seg(this.start, this.end, this.duration);
  final int start;
  final int end;
  final int duration;
}

class _Sidx {
  const _Sidx(this.timescale, this.segments, {this.mimeType = 'video/mp4'});
  final int timescale;
  final List<_Seg> segments;
  final String mimeType;

  double get durationSeconds {
    var ticks = 0;
    for (final seg in segments) {
      ticks += seg.duration;
    }
    return timescale == 0 ? 0 : ticks / timescale;
  }
}

Future<_Sidx?> _videoTrack(NewPipeVideoStream video, Uint8List? index) async {
  if (index == null) return null;
  final sidx = _parseSidx(index, video.indexEnd!);
  if (sidx != null) return sidx;
  final init = await _fetchRange(video.url!, video.initStart!, video.initEnd!);
  if (init == null) return null;
  return _parseWebmCues(
    init: init,
    index: index,
    indexEnd: video.indexEnd!,
    contentLength: video.contentLength,
    durationMs: video.approxDurationMs,
  );
}

_Sidx? _parseWebmCues({
  required Uint8List init,
  required Uint8List index,
  required int indexEnd,
  required int? contentLength,
  required int? durationMs,
}) {
  if (contentLength == null || contentLength <= 1) return null;
  if (durationMs == null || durationMs <= 0) return null;
  final payload = _segmentPayloadStart(init);
  if (payload == null) return null;
  final scaleNs = _timecodeScale(init, payload);
  if (scaleNs <= 0 || 1000000000 % scaleNs != 0) return null;
  final timescale = 1000000000 ~/ scaleNs;
  final points = _cuePoints(index);
  if (points == null ||
      points.length < 2 ||
      points.length > 10000 ||
      points.first.time != 0) {
    return null;
  }
  final totalTicks = durationMs * timescale ~/ 1000;
  final segments = <_Seg>[];
  for (var i = 0; i < points.length; i++) {
    final start = payload + points[i].position;
    final end = i + 1 < points.length
        ? payload + points[i + 1].position - 1
        : contentLength - 1;
    final duration = i + 1 < points.length
        ? points[i + 1].time - points[i].time
        : totalTicks - points[i].time;
    if (start <= indexEnd || end < start || duration <= 0) return null;
    segments.add(_Seg(start, end, duration));
  }
  return _Sidx(timescale, segments, mimeType: 'video/webm');
}

int? _segmentPayloadStart(Uint8List data) {
  var i = 0;
  while (i + 2 <= data.length) {
    final id = _readVint(data, i, keepMarker: true);
    if (id == null) return null;
    final size = _readVint(data, id.next, keepMarker: false);
    if (size == null) return null;
    if (id.value == 0x18538067) return size.next;
    if (size.unknown || size.next + size.value > data.length) return null;
    i = size.next + size.value;
  }
  return null;
}

int _timecodeScale(Uint8List data, int payload) {
  var i = payload;
  while (i + 2 <= data.length) {
    final id = _readVint(data, i, keepMarker: true);
    if (id == null) break;
    final size = _readVint(data, id.next, keepMarker: false);
    if (size == null ||
        size.unknown ||
        size.next + size.value > data.length) {
      break;
    }
    if (id.value == 0x1549A966) {
      return _uintElement(data, size.next, size.next + size.value, 0x2AD7B1) ??
          1000000;
    }
    i = size.next + size.value;
  }
  return 1000000;
}

List<_Cue>? _cuePoints(Uint8List data) {
  if (data.length < 4) return null;
  final id = _readVint(data, 0, keepMarker: true);
  if (id == null || id.value != 0x1C53BB6B) return null;
  final size = _readVint(data, id.next, keepMarker: false);
  if (size == null || size.unknown || size.next + size.value > data.length) {
    return null;
  }
  final end = size.next + size.value;
  final points = <_Cue>[];
  var i = size.next;
  while (i + 2 <= end) {
    final pointId = _readVint(data, i, keepMarker: true);
    if (pointId == null) return null;
    final pointSize = _readVint(data, pointId.next, keepMarker: false);
    if (pointSize == null ||
        pointSize.unknown ||
        pointSize.next + pointSize.value > end) {
      return null;
    }
    if (pointId.value == 0xBB) {
      final cue = _oneCue(data, pointSize.next, pointSize.next + pointSize.value);
      if (cue == null) return null;
      points.add(cue);
    }
    i = pointSize.next + pointSize.value;
  }
  return points;
}

_Cue? _oneCue(Uint8List data, int start, int end) {
  int? time;
  int? position;
  var i = start;
  while (i + 2 <= end) {
    final id = _readVint(data, i, keepMarker: true);
    if (id == null) return null;
    final size = _readVint(data, id.next, keepMarker: false);
    if (size == null || size.unknown || size.next + size.value > end) {
      return null;
    }
    if (id.value == 0xB3) {
      time = _uintBytes(data, size.next, size.value);
    } else if (id.value == 0xB7) {
      position = _uintElement(data, size.next, size.next + size.value, 0xF1);
    }
    i = size.next + size.value;
  }
  if (time == null || position == null) return null;
  return _Cue(time, position);
}

int? _uintElement(Uint8List data, int start, int end, int want) {
  var i = start;
  while (i + 2 <= end) {
    final id = _readVint(data, i, keepMarker: true);
    if (id == null) return null;
    final size = _readVint(data, id.next, keepMarker: false);
    if (size == null || size.unknown || size.next + size.value > end) {
      return null;
    }
    if (id.value == want) return _uintBytes(data, size.next, size.value);
    i = size.next + size.value;
  }
  return null;
}

int? _uintBytes(Uint8List data, int offset, int length) {
  if (length <= 0 || length > 8 || offset + length > data.length) return null;
  var value = 0;
  for (var i = 0; i < length; i++) {
    value = (value << 8) | data[offset + i];
  }
  return value;
}

class _Vint {
  const _Vint(this.value, this.next, this.unknown);
  final int value;
  final int next;
  final bool unknown;
}

_Vint? _readVint(Uint8List data, int offset, {required bool keepMarker}) {
  if (offset < 0 || offset >= data.length) return null;
  final first = data[offset];
  if (first == 0) return null;
  var mask = 0x80;
  var length = 1;
  while ((first & mask) == 0) {
    mask >>= 1;
    length += 1;
    if (length > 8) return null;
  }
  if (offset + length > data.length) return null;
  var value = keepMarker ? first : (first & (mask - 1));
  for (var i = 1; i < length; i++) {
    value = (value << 8) | data[offset + i];
  }
  final allOnes = (1 << (7 * length)) - 1;
  return _Vint(value, offset + length, !keepMarker && value == allOnes);
}

class _Cue {
  const _Cue(this.time, this.position);
  final int time;
  final int position;
}

_Sidx? _parseSidx(Uint8List data, int indexEnd) {
  if (data.length < 32) return null;
  if (data[4] != 0x73 || data[5] != 0x69 || data[6] != 0x64 || data[7] != 0x78) {
    return null;
  }
  final version = data[8];
  var p = 16;
  final timescale = _u32(data, p);
  p += 4;
  if (version == 0) {
    p += 4;
  } else {
    if (data.length < p + 8) return null;
    p += 8;
  }
  if (data.length < p + 4) return null;
  final firstOffset = version == 0 ? _u32(data, p) : _u64(data, p);
  p += version == 0 ? 4 : 8;
  if (data.length < p + 4) return null;
  p += 2;
  final count = _u16(data, p);
  p += 2;
  if (count <= 0 || count > 10000) return null;
  if (timescale == 0) return null;
  var byte = indexEnd + 1 + firstOffset;
  final segments = <_Seg>[];
  for (var i = 0; i < count; i++) {
    if (data.length < p + 12) return null;
    final size = _u32(data, p) & 0x7fffffff;
    p += 4;
    final duration = _u32(data, p);
    p += 8;
    if (size <= 0 || duration <= 0) return null;
    segments.add(_Seg(byte, byte + size - 1, duration));
    byte += size;
  }
  return _Sidx(timescale, segments);
}

int _u16(Uint8List data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

int _u32(Uint8List data, int offset) {
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

int _u64(Uint8List data, int offset) {
  return (_u32(data, offset) << 32) | _u32(data, offset + 4);
}

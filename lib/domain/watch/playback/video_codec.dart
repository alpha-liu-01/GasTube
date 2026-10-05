import 'package:fluxtube/core/settings.dart';

/// Classifies a video stream as H.264, VP9, AV1, or something else.
///
/// Codec strings from NewPipe, Piped, Invidious, and Explode differ
/// (`avc1`, `vp09`, `MPEG_4`). Container is only used when the codec
/// string is empty.
String videoCodecFamily({String? codec, String? format}) {
  final value = (codec ?? '').toLowerCase();
  if (value.startsWith('avc1') ||
      value.startsWith('avc3') ||
      value.contains('h264')) {
    return defaultVideoCodecH264;
  }
  if (value.startsWith('vp9') || value.contains('vp09') || value.contains('vp9')) {
    return defaultVideoCodecVp9;
  }
  if (value.startsWith('av01') || value.contains('av1')) return 'av1';

  final container = (format ?? '').toUpperCase();
  if (container == 'MPEG_4' || container == 'MP4') return defaultVideoCodecH264;
  if (container == 'WEBM') return defaultVideoCodecVp9;
  return 'other';
}

/// Lower rank is preferred. The chosen family is 0, the other of H.264
/// and VP9 is 1, and everything else is 2.
int videoCodecRank(String family, String preferred) {
  final want = normalizeDefaultVideoCodec(preferred);
  if (family == want) return 0;
  if (family == defaultVideoCodecH264 || family == defaultVideoCodecVp9) {
    return 1;
  }
  return 2;
}

String videoCodecDisplayName(String family) {
  switch (family) {
    case defaultVideoCodecH264:
      return 'H.264';
    case defaultVideoCodecVp9:
      return 'VP9';
    case 'av1':
      return 'AV1';
    default:
      return family;
  }
}

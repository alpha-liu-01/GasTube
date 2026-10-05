/// Playlist id from a YouTube URL, or the string itself when it is already
/// a bare id. A URL without `list=` is not an id.
String? youtubePlaylistId(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  final list = Uri.tryParse(value)?.queryParameters['list'];
  if (list != null && list.isNotEmpty) return list;
  if (value.contains('://') ||
      value.contains('/') ||
      value.contains('?') ||
      value.contains('=')) {
    return null;
  }
  return value;
}

/// Video id from a watch URL, a shorts URL, or a bare id.
String? youtubeVideoId(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  final fromQuery = Uri.tryParse(value)?.queryParameters['v'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  if (value.contains('/shorts/')) {
    final id = value.split('/shorts/').last.split('?').first.split('&').first;
    if (id.isNotEmpty) return id;
  }
  if (value.contains('://') ||
      value.contains('/') ||
      value.contains('?') ||
      value.contains('=')) {
    return null;
  }
  return value;
}

/// Last path segment of a channel URL, without a query string.
String? youtubeChannelId(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  final segments = Uri.tryParse(value)?.pathSegments;
  if (segments != null && segments.isNotEmpty && segments.last.isNotEmpty) {
    return segments.last;
  }
  final last = value.split('/').last.split('?').first;
  return last.isEmpty ? null : last;
}

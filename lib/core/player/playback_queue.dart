import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';

/// The single playback queue for the app.
///
/// It serves two roles that used to live in separate classes:
///
///  * a **user queue** — videos the viewer explicitly added via "Play next" /
///    "Add to queue". Once one exists it owns playback order and is never
///    overwritten by related-stream seeding.
///  * an **autoplay fallback** — seeded from the current video's related
///    streams by the watch screens, so "play next" still works when the viewer
///    has not queued anything. It wraps around at the end; a user queue does
///    not.
class PlaybackQueue extends ChangeNotifier {
  static final PlaybackQueue _instance = PlaybackQueue._();
  factory PlaybackQueue() => _instance;
  PlaybackQueue._();

  final List<VideoBasicInfo> _queue = [];
  int _currentIndex = -1;
  bool _userManaged = false;

  List<VideoBasicInfo> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isEmpty => _queue.isEmpty;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  /// Whether the viewer has hand-built this queue. Autoplay seeding is a no-op
  /// while this is true, and the queue does not wrap at the end.
  bool get isUserManaged => _userManaged;

  VideoBasicInfo? get current =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  VideoBasicInfo? get next => hasNext ? _queue[_currentIndex + 1] : null;

  void add(VideoBasicInfo video) {
    _userManaged = true;
    _queue.add(video);
    if (_currentIndex < 0) _currentIndex = 0;
    notifyListeners();
    log('[Queue] Added: ${video.title}, size=${_queue.length}');
  }

  void addNext(VideoBasicInfo video) {
    if (_currentIndex < 0) {
      add(video);
      return;
    }
    _userManaged = true;
    _queue.insert(_currentIndex + 1, video);
    notifyListeners();
    log('[Queue] Added next: ${video.title}');
  }

  void remove(VideoBasicInfo video) {
    removeAt(_queue.indexOf(video));
  }

  void removeAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    final video = _queue.removeAt(index);
    // Only entries *before* the cursor shift it. Removing the current entry
    // leaves the cursor on the slot the next video just moved into.
    if (index < _currentIndex) {
      _currentIndex--;
    }
    if (_queue.isEmpty) {
      _currentIndex = -1;
      _userManaged = false;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    notifyListeners();
    log('[Queue] Removed at $index: ${video.title}');
  }

  void moveTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    notifyListeners();
    log('[Queue] Moved to index: $index');
  }

  void playNext() {
    if (hasNext) {
      _currentIndex++;
      notifyListeners();
      log('[Queue] Playing next, index=$_currentIndex');
    }
  }

  /// Appends [videos] that are not already queued. Keeps the current item.
  void appendNew(List<VideoBasicInfo> videos) {
    if (videos.isEmpty || !_userManaged) return;
    final known = _queue.map((video) => video.id).toSet();
    final added = videos.where((video) => video.id.isNotEmpty && known.add(video.id));
    final next = added.toList();
    if (next.isEmpty) return;
    _queue.addAll(next);
    notifyListeners();
    log('[Queue] Appended ${next.length} videos, size=${_queue.length}');
  }

  void setQueue(List<VideoBasicInfo> videos, {int startIndex = 0}) {
    _queue.clear();
    _queue.addAll(videos);
    _currentIndex =
        _queue.isEmpty ? -1 : startIndex.clamp(0, _queue.length - 1);
    _userManaged = _queue.isNotEmpty;
    notifyListeners();
    log('[Queue] Set queue: ${videos.length} videos, current=$_currentIndex');
  }

  void clear() {
    _queue.clear();
    _currentIndex = -1;
    _userManaged = false;
    notifyListeners();
    log('[Queue] Cleared');
  }

  void shuffle() {
    if (_queue.length <= 2) return;
    // Keep whatever is playing where it is; shuffle everything after it.
    final pivot = _currentIndex < 0 ? 0 : _currentIndex + 1;
    if (_queue.length - pivot <= 1) return;
    final tail = _queue.sublist(pivot)..shuffle();
    _queue.replaceRange(pivot, _queue.length, tail);
    notifyListeners();
    log('[Queue] Shuffled ${tail.length} upcoming videos');
  }

  /// Seeds the autoplay fallback from [current]'s related streams.
  ///
  /// Does nothing to the ordering of a user-built queue — it only moves the
  /// cursor onto [current] if that video is already queued.
  void seedFromRelated({
    required VideoBasicInfo current,
    required Iterable<VideoBasicInfo> related,
  }) {
    if (current.id.isEmpty) return;

    if (_userManaged) {
      final index = _queue.indexWhere((video) => video.id == current.id);
      if (index >= 0 && index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
      }
      return;
    }

    final unique = <String, VideoBasicInfo>{current.id: current};
    for (final video in related) {
      if (video.id.isEmpty) continue;
      unique.putIfAbsent(video.id, () => video);
    }
    _queue
      ..clear()
      ..addAll(unique.values);
    _currentIndex = 0;
    notifyListeners();
    log('[Queue] Seeded ${_queue.length - 1} related videos');
  }

  /// The video to play after [currentVideoId].
  ///
  /// An autoplay-seeded queue wraps around so playback never dead-ends; a
  /// user-built queue stops at its last entry.
  VideoBasicInfo? nextAfter(String? currentVideoId) {
    if (_queue.isEmpty) return null;
    if (currentVideoId == null) return _queue.first;

    final index = _queue.indexWhere((video) => video.id == currentVideoId);

    if (index == -1) {
      // Playing something outside the queue. A user queue is a list of things
      // they asked for next, so hand back its pending head; an autoplay queue
      // just restarts.
      if (!_userManaged) return _queue.first;
      return current ?? _queue.first;
    }

    if (index == _queue.length - 1) {
      // A user queue ends when it runs out; autoplay wraps so it never
      // dead-ends.
      return _userManaged ? null : _queue.first;
    }

    return _queue[index + 1];
  }

  /// The video to play before [currentVideoId]. Mirrors [nextAfter].
  VideoBasicInfo? previousAfter(String? currentVideoId) {
    if (_queue.isEmpty || currentVideoId == null) return null;

    final index = _queue.indexWhere((video) => video.id == currentVideoId);
    if (index == -1) {
      if (!_userManaged) return _queue.length > 1 ? _queue.last : null;
      if (!hasPrevious) return null;
      final video = _queue[_currentIndex - 1];
      return video.id == currentVideoId ? null : video;
    }
    if (index == 0) {
      if (_userManaged || _queue.length < 2) return null;
      return _queue.last;
    }
    return _queue[index - 1];
  }

  /// Moves the cursor onto [videoId] when it is already queued. Used when
  /// playback advances by navigation rather than through the sheet.
  void syncCurrent(String videoId) {
    final index = _queue.indexWhere((video) => video.id == videoId);
    if (index >= 0 && index != _currentIndex) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}

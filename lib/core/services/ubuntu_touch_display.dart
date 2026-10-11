import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';

/// Asks Lomiri not to dim or lock the screen while a video is playing.
///
/// `org.freedesktop.ScreenSaver` on this image has no `Inhibit`. The request
/// that repowerd honors is `com.canonical.Unity.Screen.keepDisplayOn` on the
/// system bus. Leaving the app releases the foreground cookie. A system
/// player picture holds its own until that picture pauses for background
/// audio, so the screen can still lock while only the audio is playing.
/// Desktop builds never call this bus.
class UbuntuTouchDisplay {
  static final UbuntuTouchDisplay instance = UbuntuTouchDisplay._();

  UbuntuTouchDisplay._();

  static const _name = 'com.canonical.Unity.Screen';
  static const _path = '/com/canonical/Unity/Screen';

  final Map<String, bool> _playing = {};
  DBusClient? _client;
  DBusRemoteObject? _screen;
  int? _cookie;
  bool _foreground = true;
  bool _pictureHold = false;
  Future<void> _queue = Future<void>.value();

  /// [source] distinguishes the main player from Shorts. Either one playing
  /// in the foreground holds the request.
  void setPlaying(bool playing, {String source = 'player'}) {
    if (!UbuntuTouch.enabled) return;
    if (_playing[source] == playing) return;
    _playing[source] = playing;
    unawaited(_sync());
  }

  /// Holds the screen on while the system player is showing a picture.
  ///
  /// Leaving GasTube drops the foreground cookie, and media-hub drops its own
  /// display lock when a Charge replaces the file. The idle timer then blanks
  /// the screen while the new video is still playing. A paused picture
  /// releases this so a real lock can stay off for background audio.
  void setPictureHold(bool hold) {
    if (!UbuntuTouch.enabled) return;
    if (_pictureHold == hold) return;
    _pictureHold = hold;
    unawaited(_sync());
  }

  /// False while Lomiri is about to stop this process. The cookie has to be
  /// dropped before that, because a stopped process keeps its bus connection.
  void setForeground(bool foreground) {
    if (!UbuntuTouch.enabled) return;
    if (_foreground == foreground) return;
    _foreground = foreground;
    unawaited(_sync());
  }

  Future<void> _sync() {
    final done = _queue.then((_) => _apply());
    _queue = done.catchError((Object error) {
      print('gastube: display failed error=$error');
    });
    return done;
  }

  Future<void> _apply() async {
    final want =
        _pictureHold || (_foreground && _playing.containsValue(true));
    if (want && _cookie != null) return;
    if (!want && _cookie == null) return;
    final screen = await _object();
    if (screen == null) return;
    if (want) {
      final reply = await screen.callMethod(
        _name,
        'keepDisplayOn',
        const [],
        replySignature: DBusSignature('i'),
      );
      final cookie = reply.returnValues.first.asInt32();
      _cookie = cookie;
      print('gastube: display keep cookie=$cookie');
      return;
    }
    final cookie = _cookie;
    _cookie = null;
    if (cookie == null) return;
    await screen.callMethod(
      _name,
      'removeDisplayOnRequest',
      [DBusInt32(cookie)],
    );
    print('gastube: display release cookie=$cookie');
  }

  Future<DBusRemoteObject?> _object() async {
    final existing = _screen;
    if (existing != null) return existing;
    try {
      final client = _client ??= DBusClient.system();
      final screen = DBusRemoteObject(
        client,
        name: _name,
        path: DBusObjectPath(_path),
      );
      _screen = screen;
      return screen;
    } catch (error) {
      print('gastube: display bus failed error=$error');
      return null;
    }
  }
}

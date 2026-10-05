import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/core/services/media_controls.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';

/// Session-bus MPRIS player for desktop Linux.
///
/// Ubuntu Touch does not request [busName]. Owning it needs an AppArmor
/// abstraction, which the OpenStore review rejects. The phone's sound
/// indicator follows the media-hub session instead.
class MprisPlayer {
  static const busName = 'org.mpris.MediaPlayer2.gastube';
  static const objectPath = '/org/mpris/MediaPlayer2';

  static final MprisPlayer instance = MprisPlayer._();

  MprisPlayer._();

  DBusClient? _client;
  _MprisObject? _object;
  Future<void>? _claiming;
  NowPlaying? _item;
  bool _claimed = false;

  /// Own the bus name. Safe to call more than once.
  Future<void> claim() {
    if (UbuntuTouch.enabled) return Future<void>.value();
    return _claiming ??= _claim();
  }

  /// Drop the name so the sound indicator stops talking to this process.
  /// The session bus connection stays open for [reclaim].
  Future<void> release() async {
    if (UbuntuTouch.enabled) return;
    final client = _client;
    if (client == null || !_claimed) return;
    _claimed = false;
    try {
      final reply = await client.releaseName(busName);
      print('gastube: mpris release reply=$reply');
    } catch (error) {
      print('gastube: mpris release failed error=$error');
    }
  }

  /// Take the name back after [release] and publish the current item again.
  ///
  /// Returns false when another process still owns [busName].
  Future<bool> reclaim() async {
    if (UbuntuTouch.enabled) return true;
    await claim();
    final client = _client;
    if (client == null) return false;
    if (_claimed) return true;
    try {
      final reply = await client.requestName(busName);
      print('gastube: mpris reclaim reply=$reply');
      if (reply == DBusRequestNameReply.exists ||
          reply == DBusRequestNameReply.inQueue) {
        return false;
      }
      _claimed = true;
      final object = _object;
      final item = _item;
      if (object == null || item == null) return true;
      await object.emitPropertiesChanged(
        'org.mpris.MediaPlayer2.Player',
        changedProperties: {
          'PlaybackStatus': DBusString(_status(item)),
          'Metadata': _metadata(item),
          'CanPlay': DBusBoolean(true),
          'CanPause': DBusBoolean(true),
          'CanSeek': DBusBoolean(true),
          'CanGoNext': DBusBoolean(_canStep(item, next: true)),
          'CanGoPrevious': DBusBoolean(_canStep(item, next: false)),
        },
      );
      return true;
    } catch (error) {
      print('gastube: mpris reclaim failed error=$error');
      return false;
    }
  }

  /// Publish the current item. [seeked] tells listeners the position jumped.
  void note(NowPlaying? item, {bool seeked = false}) {
    if (UbuntuTouch.enabled) return;
    final previous = _item;
    _item = item;
    unawaited(_publish(previous, seeked: seeked));
  }

  Future<void> _claim() async {
    try {
      final client = DBusClient.session();
      final object = _MprisObject(this);
      await client.registerObject(object);
      final reply = await client.requestName(busName);
      _client = client;
      _object = object;
      _claimed = true;
      print('gastube: mpris name=$busName reply=$reply');
      print('gastube: mpris desktop=$_desktopEntry');
    } catch (error) {
      print('gastube: mpris failed error=$error');
    }
  }

  Future<void> _publish(NowPlaying? previous, {required bool seeked}) async {
    await claim();
    final object = _object;
    if (_client == null || object == null || !_claimed) return;
    final item = _item;
    final statusChanged = _status(previous) != _status(item);
    final metadataChanged = _metadataKey(previous) != _metadataKey(item);
    if (statusChanged) {
      print('gastube: mpris status=${_status(item)}');
    }
    if (metadataChanged && item != null) {
      print(
        'gastube: mpris metadata id=${item.id} title=${item.title} art=${_indicatorArt(item.artUri)}',
      );
    }
    if (seeked && item != null) {
      print(
        'gastube: mpris seeked position=${item.position.inMilliseconds}',
      );
    }
    if (!statusChanged && !metadataChanged && !seeked) return;
    final changed = <String, DBusValue>{};
    if (statusChanged || metadataChanged) {
      changed['PlaybackStatus'] = DBusString(_status(item));
      changed['Metadata'] = _metadata(item);
      changed['CanPlay'] = DBusBoolean(item != null);
      changed['CanPause'] = DBusBoolean(item != null);
      changed['CanSeek'] = DBusBoolean(item != null);
      changed['CanGoNext'] = DBusBoolean(_canStep(item, next: true));
      changed['CanGoPrevious'] = DBusBoolean(_canStep(item, next: false));
    }
    if (statusChanged || metadataChanged) {
      await object.emitPropertiesChanged(
        'org.mpris.MediaPlayer2.Player',
        changedProperties: changed,
      );
    }
    if (seeked && item != null) {
      await object.emitSignal(
        'org.mpris.MediaPlayer2.Player',
        'Seeked',
        [DBusInt64(item.position.inMicroseconds)],
      );
    }
  }

  static bool _canStep(NowPlaying? item, {required bool next}) {
    final video = next
        ? PlaybackQueue().nextAfter(item?.id)
        : PlaybackQueue().previousAfter(item?.id);
    return video != null && video.id.isNotEmpty && video.id != item?.id;
  }

  static String _status(NowPlaying? item) {
    if (item == null) return 'Stopped';
    return item.playing ? 'Playing' : 'Paused';
  }

  static String _metadataKey(NowPlaying? item) {
    if (item == null) return '';
    return '${item.id}|${item.title}|${item.artist}|${item.artUri}|${item.duration?.inMilliseconds}';
  }

  static DBusDict _metadata(NowPlaying? item) {
    if (item == null) {
      return DBusDict.stringVariant(const {});
    }
    final values = <String, DBusValue>{
      'mpris:trackid': DBusObjectPath(_trackPath(item.id)),
      'xesam:title': DBusString(item.title),
      'xesam:artist': DBusArray.string([item.artist]),
    };
    final duration = item.duration;
    if (duration != null && duration > Duration.zero) {
      values['mpris:length'] = DBusInt64(duration.inMicroseconds);
    }
    final art = _indicatorArt(item.artUri);
    if (art != null && art.isNotEmpty) {
      values['mpris:artUrl'] = DBusString(art);
    }
    return DBusDict.stringVariant(values);
  }

  /// Local icon shown beside the title. This phone's thumbnailer rejects https.
  static const _clickIconUrl =
      'file:///opt/click.ubuntu.com/gastube.alphaliu01/current/gastube.png';

  static String? _indicatorArt(String? art) {
    if (!UbuntuTouch.enabled) return art;
    if (File(_clickIconUrl.replaceFirst('file://', '')).existsSync()) {
      return _clickIconUrl;
    }
    return art;
  }

  static String get _desktopEntry {
    final appId = Platform.environment['APP_ID'];
    if (appId != null && appId.isNotEmpty) return appId;
    return 'gastube';
  }

  static String _trackPath(String id) {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return '/org/mpris/MediaPlayer2/track/$safe';
  }
}

class _MprisObject extends DBusObject {
  _MprisObject(this._player) : super(DBusObjectPath(MprisPlayer.objectPath));

  final MprisPlayer _player;

  NowPlaying? get _item => _player._item;

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectProperty property(String name, String type) {
      return DBusIntrospectProperty(
        name,
        DBusSignature(type),
        access: DBusPropertyAccess.read,
      );
    }

    DBusIntrospectMethod method(String name,
        [List<DBusIntrospectArgument>? args]) {
      return DBusIntrospectMethod(name, args: args ?? const []);
    }

    return [
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2',
        methods: [method('Raise'), method('Quit')],
        properties: [
          property('CanQuit', 'b'),
          property('CanRaise', 'b'),
          property('HasTrackList', 'b'),
          property('Identity', 's'),
          property('DesktopEntry', 's'),
          property('SupportedUriSchemes', 'as'),
          property('SupportedMimeTypes', 'as'),
        ],
      ),
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2.Player',
        methods: [
          method('Next'),
          method('Previous'),
          method('Pause'),
          method('PlayPause'),
          method('Stop'),
          method('Play'),
          method('Seek', [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
              name: 'Offset',
            ),
          ]),
          method('SetPosition', [
            DBusIntrospectArgument(
              DBusSignature('o'),
              DBusArgumentDirection.in_,
              name: 'TrackId',
            ),
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
              name: 'Position',
            ),
          ]),
          method('OpenUri', [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'Uri',
            ),
          ]),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: [
          property('PlaybackStatus', 's'),
          property('LoopStatus', 's'),
          property('Rate', 'd'),
          property('Shuffle', 'b'),
          property('Metadata', 'a{sv}'),
          property('Volume', 'd'),
          property('Position', 'x'),
          property('MinimumRate', 'd'),
          property('MaximumRate', 'd'),
          property('CanGoNext', 'b'),
          property('CanGoPrevious', 'b'),
          property('CanPlay', 'b'),
          property('CanPause', 'b'),
          property('CanSeek', 'b'),
          property('CanControl', 'b'),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = _properties(interface)[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final values = _properties(interface);
    if (values.isEmpty &&
        interface != 'org.mpris.MediaPlayer2' &&
        interface != 'org.mpris.MediaPlayer2.Player') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    return DBusGetAllPropertiesResponse(values);
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    return DBusMethodErrorResponse.propertyReadOnly();
  }

  Map<String, DBusValue> _properties(String interface) {
    final item = _item;
    if (interface == 'org.mpris.MediaPlayer2') {
      return {
        'CanQuit': const DBusBoolean(false),
        'CanRaise': const DBusBoolean(false),
        'HasTrackList': const DBusBoolean(false),
        'Identity': const DBusString('GasTube'),
        'DesktopEntry': DBusString(MprisPlayer._desktopEntry),
        'SupportedUriSchemes': DBusArray.string(const ['https', 'http']),
        'SupportedMimeTypes': DBusArray.string(const [
          'video/mp4',
          'video/webm',
          'audio/mp4',
        ]),
      };
    }
    if (interface == 'org.mpris.MediaPlayer2.Player') {
      final controllable = item != null;
      return {
        'PlaybackStatus': DBusString(MprisPlayer._status(item)),
        'LoopStatus': const DBusString('None'),
        'Rate': const DBusDouble(1),
        'Shuffle': const DBusBoolean(false),
        'Metadata': MprisPlayer._metadata(item),
        'Volume': const DBusDouble(1),
        'Position': DBusInt64(item?.position.inMicroseconds ?? 0),
        'MinimumRate': const DBusDouble(1),
        'MaximumRate': const DBusDouble(1),
        'CanGoNext': DBusBoolean(MprisPlayer._canStep(item, next: true)),
        'CanGoPrevious': DBusBoolean(MprisPlayer._canStep(item, next: false)),
        'CanPlay': DBusBoolean(controllable),
        'CanPause': DBusBoolean(controllable),
        'CanSeek': DBusBoolean(controllable),
        'CanControl': const DBusBoolean(true),
      };
    }
    return const {};
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final interface = methodCall.interface;
    if (interface == 'org.mpris.MediaPlayer2') {
      return DBusMethodSuccessResponse();
    }
    if (interface != 'org.mpris.MediaPlayer2.Player') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final controls = MediaControls.instance;
    switch (methodCall.name) {
      case 'Play':
        print('gastube: mpris command=Play');
        await controls.sessionPlay();
      case 'Pause':
        print('gastube: mpris command=Pause');
        await controls.sessionPause();
      case 'PlayPause':
        print('gastube: mpris command=PlayPause');
        if (_item?.playing ?? false) {
          await controls.sessionPause();
        } else {
          await controls.sessionPlay();
        }
      case 'Stop':
        print('gastube: mpris command=Stop');
        await controls.sessionPause();
      case 'Seek':
        final offset = _int64(methodCall.values);
        print('gastube: mpris command=Seek offset=$offset');
        final current = _item?.position ?? Duration.zero;
        final next = current + Duration(microseconds: offset);
        await controls.sessionSeek(next < Duration.zero ? Duration.zero : next);
      case 'SetPosition':
        if (methodCall.values.length < 2) break;
        final track = methodCall.values[0];
        final position = _int64([methodCall.values[1]]);
        final wanted = _item == null ? '' : MprisPlayer._trackPath(_item!.id);
        if (track is DBusObjectPath && track.value == wanted) {
          print('gastube: mpris command=SetPosition position=$position');
          final next = Duration(microseconds: position);
          await controls.sessionSeek(
            next < Duration.zero ? Duration.zero : next,
          );
        }
      case 'Next':
        print('gastube: mpris command=Next');
        await controls.sessionNext();
      case 'Previous':
        print('gastube: mpris command=Previous');
        await controls.sessionPrevious();
      case 'OpenUri':
        break;
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  int _int64(List<DBusValue> values) {
    if (values.isEmpty) return 0;
    final value = values.first;
    if (value is DBusInt64) return value.value;
    return 0;
  }
}

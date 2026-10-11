import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:fluxtube/infrastructure/database/database.dart';

/// Fullscreen button follows the video's aspect. Default off.
///
/// While fullscreen, rotation stays inside the two directions of that aspect.
/// A landscape video allows landscape left and right. A portrait video allows
/// portrait up and down. Leaving fullscreen follows the phone again. The main
/// screen is not locked to portrait, including when the shorter side is under
/// [WindowLayout.sideRailMinWidth].
///
/// Android and iOS ask the system for that set. Ubuntu Touch does not honor
/// the request, so the page itself turns when the window is in a locked-out
/// direction and turns back when the window is already allowed.
class FullscreenAspect {
  static bool enabled = false;
  static bool _loaded = false;
  static int _session = 0;
  static bool? _allowedLandscape;
  static bool? _idleIsPhone;
  static bool _observing = false;

  /// 0 top-up, 1 right-up, 2 top-down, 3 left-up. Null until the sensor speaks.
  static int? _deviceQ;

  /// 1 or 3. Remembered from the last sideways hold so a later portrait
  /// frame does not flip the page the other way. [_latchedOdd] assumes the
  /// shell has kept the window upright. [_latchedOddFixed] assumes the
  /// window is stuck to the phone, which is what rotation lock does.
  static int? _latchedOdd;
  static int? _latchedOddFixed;
  static bool _shellFixed = false;
  static bool? _windowLandscape;
  static DateTime? _disagreeSince;
  static Timer? _shellFixedTimer;
  static bool _sensorStarted = false;
  static DBusRemoteObject? _sensor;
  static Socket? _sensorSocket;
  static Timer? _sensorTimer;
  static final List<int> _sensorPending = <int>[];
  static bool _sensorTagPending = true;

  static final turns = ValueNotifier<int>(0);

  static const _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const _portrait = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
  static const _channel = MethodChannel('com.alexmercerind/media_kit_video');
  static final _metrics = _FullscreenAspectMetrics();

  static bool get sessionActive => _session > 0;

  static Future<void> ensureLoaded() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(_metrics);
    }
    if (_loaded) return;
    final stored =
        await AppDatabase.instance.getSetting(fullscreenAspectRotateKey);
    enabled = stored == 'true';
    _loaded = true;
    if (UbuntuTouch.enabled) {
      unawaited(_ensureSensor());
    }
    if (enabled) {
      await applyIdle();
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    _loaded = true;
    await AppDatabase.instance.setSetting(
      fullscreenAspectRotateKey,
      value ? 'true' : 'false',
    );
    if (!value) {
      _allowedLandscape = null;
      _idleIsPhone = null;
      turns.value = 0;
      if (_session == 0) {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
      return;
    }
    if (_session == 0) {
      await applyIdle();
    }
  }

  /// media_kit fullscreen entry. False leaves the previous landscape policy.
  static Future<bool> handleMediaKitEnter() async {
    await ensureLoaded();
    if (!enabled) return false;
    final size = _playingSize();
    await _enterChrome();
    await choose(size.$1, size.$2);
    return true;
  }

  /// media_kit fullscreen exit. False leaves the previous exit policy.
  static Future<bool> handleMediaKitExit() async {
    if (_session == 0) return false;
    await _exitChrome();
    await restore();
    return true;
  }

  /// Pick a direction. Does nothing while the switch is off.
  static Future<void> choose(int? width, int? height) async {
    await ensureLoaded();
    if (!enabled) return;
    _session++;
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        width == height) {
      print('gastube: fullscreen aspect keep size=${width}x$height');
      return;
    }
    final wantLandscape = width > height;
    _allowedLandscape = wantLandscape;
    await SystemChrome.setPreferredOrientations(
      wantLandscape ? _landscape : _portrait,
    );
    _observeShell();
    _syncTurns();
    print(
      'gastube: fullscreen aspect lock='
      '${wantLandscape ? 'landscape' : 'portrait'} '
      'size=${width}x$height turns=${turns.value}',
    );
  }

  /// Leave fullscreen. The main screen follows the phone in either aspect.
  static Future<void> restore() async {
    if (_session == 0) return;
    _session--;
    if (_session > 0) return;
    _allowedLandscape = null;
    await applyIdle();
    print(
      'gastube: fullscreen aspect exit '
      'phone=${_idleIsPhone == true} turns=${turns.value}',
    );
  }

  /// The main screen follows the phone. A short side does not force portrait.
  static Future<void> applyIdle() async {
    if (!enabled || _session > 0) return;
    final side = _shorterLogicalSide();
    if (side <= 0) return;
    _idleIsPhone = side < WindowLayout.sideRailMinWidth;
    _allowedLandscape = null;
    turns.value = 0;
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    print('gastube: fullscreen aspect idle follow side=$side');
  }

  static void onMetrics() {
    if (!enabled) return;
    _observeShell();
    if (_session > 0) {
      _syncTurns();
      return;
    }
    final side = _shorterLogicalSide();
    if (side <= 0) return;
    final phone = side < WindowLayout.sideRailMinWidth;
    if (_idleIsPhone != phone) {
      unawaited(applyIdle());
      return;
    }
    _syncTurns();
  }

  static void _syncTurns() {
    final allowed = _allowedLandscape;
    if (allowed == null || Platform.isAndroid || Platform.isIOS) {
      turns.value = 0;
      return;
    }
    final mismatch = allowed != _viewIsLandscape();
    final fixed = _shellFixed && _session > 0;
    final next = !mismatch
        ? 0
        : fixed
            ? (_latchedOddFixed ?? _defaultOddFixed())
            : (_latchedOdd ?? _defaultOdd());
    if (turns.value != next) {
      turns.value = next;
      print(
        'gastube: fullscreen aspect turns=$next device=$_deviceQ '
        'fixed=$_shellFixed',
      );
    }
  }

  /// Page top toward the phone's top while Lomiri keeps the window upright.
  /// Right-up is a normal grip turned 90 degrees counterclockwise.
  static int _defaultOdd() {
    final device = _deviceQ;
    if (device == 1 || device == 2) return 3;
    return 1;
  }

  /// Same goal when rotation lock has glued the window to the phone, so the
  /// window's top is the phone's top instead of the sky. The upright quarter
  /// turn is the opposite of [_defaultOdd].
  static int _defaultOddFixed() {
    final device = _deviceQ;
    if (device == 1 || device == 2) return 1;
    return 3;
  }

  /// Rotation lock leaves the window aspect unchanged while the phone turns.
  /// A short disagreement is the shell's rotate animation. Sensor reads keep
  /// arriving every 250ms, so the wait must not restart on each of them.
  static void _observeShell() {
    final windowLandscape = _viewIsLandscape();
    if (_windowLandscape != null && _windowLandscape != windowLandscape) {
      _shellFixed = false;
      _cancelShellWait();
    }
    _windowLandscape = windowLandscape;
    final device = _deviceQ;
    if (device == null) return;
    final deviceLandscape = device == 1 || device == 3;
    if (deviceLandscape == windowLandscape) {
      _cancelShellWait();
      return;
    }
    if (_shellFixed) return;
    final now = DateTime.now();
    if (_disagreeSince == null) {
      _disagreeSince = now;
      _shellFixedTimer ??= Timer(const Duration(milliseconds: 800), () {
        _shellFixedTimer = null;
        _observeShell();
      });
      return;
    }
    if (now.difference(_disagreeSince!) < const Duration(milliseconds: 800)) {
      return;
    }
    _shellFixed = true;
    _cancelShellWait();
    _syncTurns();
    print(
      'gastube: fullscreen aspect shell fixed device=$device '
      'turns=${turns.value}',
    );
  }

  static void _cancelShellWait() {
    _disagreeSince = null;
    _shellFixedTimer?.cancel();
    _shellFixedTimer = null;
  }

  static Future<void> _ensureSensor() async {
    if (_sensorStarted) return;
    _sensorStarted = true;
    try {
      final client = DBusClient.system();
      final manager = DBusRemoteObject(
        client,
        name: 'com.nokia.SensorService',
        path: DBusObjectPath('/SensorManager'),
      );
      final requested = await manager.callMethod(
        'local.SensorManager',
        'requestSensor',
        [DBusString('orientationsensor'), DBusInt64(0)],
        replySignature: DBusSignature('i'),
      );
      final session = requested.returnValues[0].asInt32();
      final socket = await Socket.connect(
        InternetAddress('/run/sensord.sock', type: InternetAddressType.unix),
        0,
      );
      final bytes = ByteData(4)..setInt32(0, session, Endian.little);
      socket.add(bytes.buffer.asUint8List());
      await socket.flush();
      _sensorSocket = socket;
      // sensorfw writes a one-byte tag as soon as the socket connects, then
      // the pose samples. The tag has to be read before start(), or the
      // daemon's write sits in the send buffer and the dbus reply never
      // comes back.
      socket.listen(
        _onSensorBytes,
        onError: (Object error) {
          print('gastube: fullscreen aspect sensor failed error=$error');
        },
      );
      final sensor = DBusRemoteObject(
        client,
        name: 'com.nokia.SensorService',
        path: DBusObjectPath('/SensorManager/orientationsensor'),
      );
      _sensor = sensor;
      try {
        await _pollSensor().timeout(const Duration(seconds: 2));
      } catch (error) {
        print('gastube: fullscreen aspect sensor read failed error=$error');
      }
      try {
        await sensor
            .callMethod(
              'local.OrientationSensor',
              'start',
              [DBusInt32(session)],
              replySignature: DBusSignature(''),
            )
            .timeout(const Duration(seconds: 2));
        print('gastube: fullscreen aspect sensor started session=$session');
      } catch (error) {
        print('gastube: fullscreen aspect sensor start failed error=$error');
      }
      _sensorTimer ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_pollSensor()),
      );
    } catch (error) {
      print('gastube: fullscreen aspect sensor failed error=$error');
    }
  }

  /// First byte is the handshake tag. Later bytes are packets of
  /// count plus that many 16-byte TimedUnsigned samples.
  static void _onSensorBytes(List<int> chunk) {
    if (_sensorSocket == null) return;
    _sensorPending.addAll(chunk);
    if (_sensorTagPending && _sensorPending.isNotEmpty) {
      if (_sensorPending.first == 0x0A) {
        _sensorPending.removeAt(0);
      }
      _sensorTagPending = false;
    }
    final data = Uint8List.fromList(_sensorPending);
    var offset = 0;
    while (data.length - offset >= 4) {
      final count = ByteData.sublistView(data, offset, offset + 4)
          .getUint32(0, Endian.little);
      if (count == 0 || count > 8) {
        offset += 1;
        continue;
      }
      final stride = _sampleStride(data, offset, count);
      if (stride == null) {
        offset += 1;
        continue;
      }
      final packet = 4 + count * stride;
      if (data.length - offset < packet) break;
      for (var i = 0; i < count; i++) {
        final pose = ByteData.sublistView(
          data,
          offset + 4 + i * stride + 8,
          offset + 4 + i * stride + 12,
        ).getUint32(0, Endian.little);
        _applySensor(pose);
      }
      offset += packet;
    }
    _sensorPending
      ..clear()
      ..addAll(data.sublist(offset));
  }

  static int? _sampleStride(Uint8List data, int offset, int count) {
    final available = data.length - offset;
    var short = false;
    for (final stride in const [16, 12]) {
      final packet = 4 + count * stride;
      if (available < packet) {
        short = true;
        continue;
      }
      final pose = ByteData.sublistView(
        data,
        offset + 12,
        offset + 16,
      ).getUint32(0, Endian.little);
      if (pose >= 1 && pose <= 6) return stride;
    }
    if (short && available < 4 + count * 12) return 16;
    return null;
  }

  static Future<void> _pollSensor() async {
    final sensor = _sensor;
    if (sensor == null) return;
    try {
      final reading = await sensor
          .callMethod(
            'local.OrientationSensor',
            'orientation',
            const [],
            replySignature: DBusSignature('(tu)'),
          )
          .timeout(const Duration(seconds: 2));
      if (reading.returnValues.isEmpty) return;
      _applySensor(_orientationOf(reading.returnValues.first));
    } catch (error) {
      print('gastube: fullscreen aspect sensor read failed error=$error');
      _sensorTimer?.cancel();
      _sensorTimer = null;
      _sensor = null;
    }
  }

  static int? _orientationOf(DBusValue value) {
    if (value is DBusStruct && value.children.length >= 2) {
      return _asInt(value.children[1]);
    }
    return _asInt(value);
  }

  static int? _asInt(DBusValue value) {
    if (value is DBusUint32) return value.value;
    if (value is DBusInt32) return value.value;
    return null;
  }

  /// sensorfw pose: 1 left-up, 2 right-up, 3 top-down, 4 top-up.
  static void _applySensor(int? raw) {
    final device = switch (raw) {
      4 => 0,
      2 => 1,
      3 => 2,
      1 => 3,
      _ => null,
    };
    if (device == null) return;
    final changed = _deviceQ != device;
    _deviceQ = device;
    if (device == 1) {
      _latchedOdd = 3;
      _latchedOddFixed = 1;
    }
    if (device == 3) {
      _latchedOdd = 1;
      _latchedOddFixed = 3;
    }
    _observeShell();
    if (!changed || !enabled) return;
    _syncTurns();
    print(
      'gastube: fullscreen aspect sensor q=$device '
      'latch=$_latchedOdd turns=${turns.value}',
    );
  }

  static (int?, int?) _playingSize() {
    try {
      final state = GlobalPlayerController().player.state;
      final width = state.width;
      final height = state.height;
      if (width != null && height != null && width > 0 && height > 0) {
        return (width, height);
      }
      final params = state.videoParams;
      var w = params.w;
      var h = params.h;
      final rotate = params.rotate ?? 0;
      if (rotate == 90 || rotate == 270) {
        final swap = w;
        w = h;
        h = swap;
      }
      return (w, h);
    } catch (error) {
      print('gastube: fullscreen aspect size failed error=$error');
      return (null, null);
    }
  }

  static bool _viewIsLandscape() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return true;
    final size = views.first.physicalSize;
    return size.width > size.height;
  }

  static double _shorterLogicalSide() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final view = views.first;
    if (view.devicePixelRatio == 0) return 0;
    final logical = view.physicalSize / view.devicePixelRatio;
    if (logical.width <= 0 || logical.height <= 0) return 0;
    return logical.width < logical.height ? logical.width : logical.height;
  }

  static Future<void> _enterChrome() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        await _channel.invokeMethod<void>('Utils.EnterNativeFullscreen');
      }
    } catch (error) {
      print('gastube: fullscreen aspect enter chrome failed error=$error');
    }
  }

  static Future<void> _exitChrome() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        await _channel.invokeMethod<void>('Utils.ExitNativeFullscreen');
      }
    } catch (error) {
      print('gastube: fullscreen aspect exit chrome failed error=$error');
    }
  }
}

class _FullscreenAspectMetrics extends WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    FullscreenAspect.onMetrics();
  }
}

/// Rotates the page when the window is in a direction the current lock rejects.
class FullscreenAspectScope extends StatelessWidget {
  const FullscreenAspectScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FullscreenAspect.turns,
      builder: (context, quarterTurns, child) {
        final turns = quarterTurns % 4;
        if (turns == 0) return child!;
        final query = MediaQuery.of(context);
        final size = query.size;
        final data = turns.isOdd
            ? query.copyWith(size: Size(size.height, size.width))
            : query;
        return RotatedBox(
          quarterTurns: turns,
          child: MediaQuery(
            data: data,
            child: child!,
          ),
        );
      },
      child: child,
    );
  }
}

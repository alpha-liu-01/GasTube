import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/infrastructure/database/database.dart';

/// Whole-window fullscreen, separate from the video player's own fullscreen.
///
/// The choice is stored in the settings table and applied again on the next
/// launch. Leaving the video player's fullscreen does not restore the title
/// bar while this stays on.
class WindowFullscreen {
  static const _channel = MethodChannel('com.alexmercerind/media_kit_video');

  static bool _enabled = false;

  static bool get enabled => _enabled;

  static bool get isSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  static Future<void> loadAndApply() async {
    if (!isSupported) return;
    final stored = await AppDatabase.instance.getSetting(windowFullscreenKey);
    _enabled = stored == 'true';
    if (_enabled) {
      await _push(enter: true);
    }
  }

  static Future<void> setEnabled(bool value) async {
    if (!isSupported) return;
    _enabled = value;
    await AppDatabase.instance.setSetting(
      windowFullscreenKey,
      value ? 'true' : 'false',
    );
    await _push(enter: value);
  }

  static Future<void> _push({required bool enter}) async {
    await _channel.invokeMethod<void>('Utils.SetAppFullscreen', _enabled);
    await _channel.invokeMethod<void>(
      enter ? 'Utils.EnterNativeFullscreen' : 'Utils.ExitNativeFullscreen',
    );
  }
}

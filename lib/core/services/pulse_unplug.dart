import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/core/services/media_hub_player.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';

/// Pauses playback when Pulse reports that a wired headphone or headset port
/// is no longer available. Android keeps its own audio-session path.
class PulseUnplug {
  static const _channel = MethodChannel('lol.alphaliu01.gastube/pulse');
  static bool _listening = false;

  static void listen() {
    if (!Platform.isLinux || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'unplug') return;
      print('gastube: pulse unplug');
      if (UbuntuTouch.enabled &&
          await MediaHubPlayer.instance.pauseIfAway()) {
        return;
      }
      await GlobalPlayerController().pausePlayback();
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_related.dart';
import 'package:fluxtube/infrastructure/database/database.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_channel.dart';

/// Notifies about new uploads from subscribed channels.
///
/// Checks run in the foreground — on startup and when the app returns from the
/// background — throttled to [_minCheckInterval]. There is no periodic
/// background job. Desktop Linux and Ubuntu Touch post through the session
/// notification service. Ubuntu Push is not used.
///
/// State lives in the settings table so it survives restarts:
///  * [notifyNewVideosKey] — whether the feature is on,
///  * [notifyLastCheckKey] — when the last check ran, for throttling,
///  * [notifySeenVideosKey] — the newest video id already seen per channel.
class SubscriptionNotifier extends ChangeNotifier {
  static final SubscriptionNotifier _instance = SubscriptionNotifier._();
  factory SubscriptionNotifier() => _instance;
  SubscriptionNotifier._();

  static const _minCheckInterval = Duration(hours: 3);

  /// Channels examined per run. Each one is a full extractor call, so the whole
  /// subscription list is not swept at once.
  static const _maxChannelsPerRun = 15;

  /// Notifications raised per channel per run, so a channel that uploaded a
  /// large batch cannot bury everything else.
  static const _maxNotificationsPerChannel = 3;

  static const _channelId = 'new_videos';
  static const _channelName = 'New Videos';

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _checking = false;

  bool? _enabled;

  /// Whether new-upload notifications are on. Null until first read.
  bool get isEnabled => _enabled ?? false;

  AppDatabase get _db => AppDatabase.instance;

  /// Android, iOS, desktop Linux, and Ubuntu Touch can present a notification.
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isLinux;

  Future<bool> loadEnabled() async {
    final raw = await _db.getSetting(notifyNewVideosKey);
    _enabled = raw == 'true';
    notifyListeners();
    return _enabled!;
  }

  /// Turns the feature on or off. Enabling asks for the notification
  /// permission and returns false when it is refused, so the caller can leave
  /// the switch off.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _ensurePermission();
      if (!granted) {
        _enabled = false;
        await _db.setSetting(notifyNewVideosKey, 'false');
        notifyListeners();
        return false;
      }
    }
    _enabled = enabled;
    await _db.setSetting(notifyNewVideosKey, enabled.toString());
    notifyListeners();
    return enabled;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open');
    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      ),
    );
    _initialized = true;
  }

  Future<bool> _ensurePermission() async {
    if (!isSupported) return false;
    try {
      await initialize();
      if (Platform.isLinux) return true;
      if (Platform.isAndroid) {
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // Null on Android 12 and below, where no runtime grant is needed.
        return await android?.requestNotificationsPermission() ?? true;
      }
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          true;
    } catch (e) {
      print('gastube: subscription permission failed error=$e');
      dev.log('permission request failed: $e', name: 'SubNotifier');
      return false;
    }
  }

  /// Checks subscribed channels for uploads newer than the last seen one and
  /// raises a notification for each.
  ///
  /// Pass [force] to skip the throttle. Returns how many notifications were
  /// raised, so callers can log or surface the result.
  Future<int> checkForNewVideos({bool force = false}) async {
    if (!isSupported || _checking) return 0;
    if (_enabled == null) await loadEnabled();
    if (!_enabled!) return 0;

    if (!force && !await _throttleElapsed()) {
      print('gastube: subscription skip reason=throttle');
      return 0;
    }
    if (!await NewPipeChannel.isAvailable) {
      print('gastube: subscription skip reason=sidecar');
      return 0;
    }

    _checking = true;
    var notified = 0;
    try {
      await initialize();

      final profile = await _db.getSetting(currentProfileKey) ?? 'default';
      final subscriptions = await _db.getAllSubscriptions(profile);
      if (subscriptions.isEmpty) {
        await _stampCheck();
        return 0;
      }

      final seen = await _loadSeen();
      // Round-robin: channels not looked at recently go first, so a
      // subscription list longer than _maxChannelsPerRun still gets covered
      // across successive checks.
      final ordered = [...subscriptions]..sort((a, b) {
          final aSeen = seen.containsKey(a.channelId) ? 1 : 0;
          final bSeen = seen.containsKey(b.channelId) ? 1 : 0;
          return aSeen.compareTo(bSeen);
        });

      for (final sub in ordered.take(_maxChannelsPerRun)) {
        notified += await _checkChannel(sub.channelId, sub.channelName, seen);
      }

      await _saveSeen(seen);
      await _stampCheck();
      print(
        'gastube: subscription check channels=${subscriptions.length} '
        'notified=$notified',
      );
    } catch (e) {
      print('gastube: subscription check failed error=$e');
      dev.log('check failed: $e', name: 'SubNotifier');
    } finally {
      _checking = false;
    }
    return notified;
  }

  Future<int> _checkChannel(
    String channelId,
    String channelName,
    Map<String, String> seen,
  ) async {
    if (channelId.isEmpty) return 0;
    try {
      final channel = await NewPipeChannel.getChannel(channelId);
      final uploads = channel.videos ?? const <NewPipeRelatedStream>[];
      if (uploads.isEmpty) return 0;

      final latestId = _videoId(uploads.first);
      if (latestId == null) return 0;

      final baseline = seen[channelId];
      seen[channelId] = latestId;

      // First time this channel is checked: record where it stands but stay
      // quiet, otherwise enabling the feature would notify the whole backlog.
      if (baseline == null) {
        print('gastube: subscription baseline channel=$channelId');
        return 0;
      }
      if (baseline == latestId) return 0;

      // Everything above the baseline is new. If the baseline has fallen off
      // the first page, fall back to the newest upload alone rather than
      // announcing the entire page.
      final fresh = <NewPipeRelatedStream>[];
      var foundBaseline = false;
      for (final upload in uploads) {
        if (_videoId(upload) == baseline) {
          foundBaseline = true;
          break;
        }
        if (upload.isLive == true) continue;
        fresh.add(upload);
      }
      final toNotify = (foundBaseline ? fresh : fresh.take(1).toList())
          .take(_maxNotificationsPerChannel)
          .toList();

      for (final upload in toNotify) {
        await _notify(channelId, channelName, upload);
      }
      return toNotify.length;
    } catch (e) {
      print('gastube: subscription channel failed error=$e');
      dev.log('channel $channelId failed: $e', name: 'SubNotifier');
      return 0;
    }
  }

  Future<void> _notify(
    String channelId,
    String channelName,
    NewPipeRelatedStream upload,
  ) async {
    final videoId = _videoId(upload);
    if (videoId == null) return;
    print('gastube: subscription notify channel=$channelName video=$videoId');
    if (Platform.isLinux) {
      await _notifyLinux(channelName, upload.name ?? 'New video');
      return;
    }
    await _notifications.show(
      videoId.hashCode & 0x7fffffff,
      channelName,
      upload.name ?? 'New video',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'New uploads from your subscriptions',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Collapses each channel's uploads into one expandable group.
          groupKey: channelId,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: videoId,
    );
  }

  /// Session notification. Lomiri matches [desktop-entry] to the Click desktop
  /// file, so the bubble uses GasTube's name and icon.
  Future<void> _notifyLinux(String title, String body) async {
    final client = DBusClient.session();
    try {
      final notifications = DBusRemoteObject(
        client,
        name: 'org.freedesktop.Notifications',
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      );
      await notifications.callMethod(
        'org.freedesktop.Notifications',
        'Notify',
        [
          const DBusString('GasTube'),
          const DBusUint32(0),
          DBusString(_notificationIcon),
          DBusString(title),
          DBusString(body),
          DBusArray.string(const []),
          DBusDict.stringVariant({
            'desktop-entry': DBusString(_desktopEntry),
          }),
          const DBusInt32(-1),
        ],
        replySignature: DBusSignature('u'),
      );
    } finally {
      await client.close();
    }
  }

  static String get _notificationIcon {
    const clickIcon =
        '/opt/click.ubuntu.com/gastube.alphaliu01/current/gastube.png';
    if (File(clickIcon).existsSync()) return clickIcon;
    return '';
  }

  static String get _desktopEntry {
    final appId = Platform.environment['APP_ID'];
    if (appId != null && appId.isNotEmpty) return appId;
    return 'gastube';
  }

  /// NewPipe returns full watch URLs; the notification key is the video id.
  static String? _videoId(NewPipeRelatedStream stream) {
    final url = stream.url;
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    final fromQuery = uri?.queryParameters['v'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    final tail = url.split('/').last;
    return tail.isEmpty ? null : tail;
  }

  Future<bool> _throttleElapsed() async {
    final raw = await _db.getSetting(notifyLastCheckKey);
    final last = DateTime.tryParse(raw ?? '');
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minCheckInterval;
  }

  Future<void> _stampCheck() =>
      _db.setSetting(notifyLastCheckKey, DateTime.now().toIso8601String());

  Future<Map<String, String>> _loadSeen() async {
    final raw = await _db.getSetting(notifySeenVideosKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSeen(Map<String, String> seen) =>
      _db.setSetting(notifySeenVideosKey, jsonEncode(seen));
}

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:fluxtube/core/deep_link_handler.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:path/path.dart' as p;

/// Opens an http(s) video in Media Player without downloading it first.
///
/// Content Hub passes the URL through as the item address. `mediaplayer-app`
/// plays that address. Launching it with `lomiri-app-launch` from this
/// profile cannot talk to systemd, so this is the handoff the profile allows.
Future<({bool ok, String message})> openUrlInSystemPlayer(String url) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    const peer = 'mediaplayer-app';
    final state = await _chargeItem(
      client,
      hub,
      peer: peer,
      contentType: 'videos',
      name: 'video',
      url: url,
    );
    if (state == 5) {
      print('gastube: open system url failed peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: open system url peer=$peer state=$state');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: open system url failed error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

/// Position stored for [url], without writing a seek or clearing the file.
///
/// The player file wins when it is at least five seconds. Otherwise the copy
/// written before the last handoff is used. Looking at the placeholder must
/// not ask the helper to seek.
Future<Duration?> peekSystemPlayerPosition(String url) async {
  final wanted = _playerSettingsKey(url);
  final fromFile = await _storedMsForKey(wanted);
  // -1 means the video finished. The older bookmark must not look like
  // the position they just left.
  if (fromFile != null && fromFile < 0) return null;
  if (fromFile != null && fromFile >= _resumeMinMs) {
    return Duration(milliseconds: fromFile);
  }
  final remembered = await _rememberedMs(wanted);
  if (remembered != null && remembered >= _resumeMinMs) {
    return Duration(milliseconds: remembered);
  }
  return null;
}

/// Writes [position] as the bookmark for [url], without asking the helper to seek.
///
/// Background audio uses this when the listener comes back, so the next
/// system-player open continues from the audio instead of the older picture.
Future<void> noteSystemPlayerBookmark(String url, Duration position) async {
  final ms = position.inMilliseconds;
  if (ms <= 0) return;
  final wanted = _playerSettingsKey(url);
  await _rememberMs(wanted, ms);
  await _writePlayerMs(wanted, ms);
}

/// The system player writes -1 when playback reaches the end.
///
/// A later open that has not reached the end stores a positive position, or
/// 0 when resume was cleared. Those are not the end.
Future<bool> systemPlayerReachedEnd(String url) async {
  final stored = await _storedMsForKey(_playerSettingsKey(url));
  return stored != null && stored < 0;
}

/// Drops the resume bookmark for [url] so the next open starts at the beginning.
Future<void> forgetSystemPlayerResume(String url) async {
  await clearSystemPlayerStoredPosition(url);
  final wanted = _playerSettingsKey(url);
  final file = await _resumeDirFile('gastube-resume.txt');
  if (file.existsSync()) {
    final lines = file.readAsLinesSync();
    if (lines.length >= 2 && lines[1] == wanted) {
      await file.writeAsString('');
    }
  }
  await _writePendingSeek(0, '');
}

/// Milliseconds the system player stored for [url].
///
/// The player keeps the part after the last `/`, and percent-encodes it in
/// the ini file. A stored value below five seconds is a later open that
/// already started from the beginning. The real minutes are kept in
/// `gastube-resume.txt`, because that failed open overwrites the player file.
///
/// When the seek helper is running, the player file is set to 0 so its
/// Continue dialog does not call play() from the start. The helper seeks the
/// new media-hub session after this process has been stopped.
///
/// [carry] is the position of the session just left. A quality change passes
/// it so the new address does not resume its own older bookmark.
Future<Duration?> systemPlayerStoredPosition(
  String url, {
  Duration? carry,
}) async {
  final wanted = _playerSettingsKey(url);
  final carried = carry?.inMilliseconds;
  final fromFile = await _storedMsForKey(wanted);
  final remembered = await _rememberedMs(wanted);
  int? ms;
  if (carried != null && carried >= _resumeMinMs) {
    ms = carried;
    print('gastube: system player resume carry ms=$ms');
  } else if (fromFile != null && fromFile < 0) {
    ms = null;
  } else {
    ms = fromFile != null && fromFile >= _resumeMinMs ? fromFile : null;
    if (ms == null && remembered != null && remembered >= _resumeMinMs) {
      ms = remembered;
      print('gastube: system player resume restore ms=$ms');
    }
  }
  if (ms == null) {
    if (fromFile != null && fromFile > 0 && fromFile < _resumeMinMs) {
      await clearSystemPlayerStoredPosition(url);
      print('gastube: system player resume discard ms=$fromFile');
    }
    await _writePendingSeek(0, '');
    return null;
  }
  await _rememberMs(wanted, ms);
  if (await _seekHelperAlive()) {
    await _writePendingSeek(ms, wanted);
    await clearSystemPlayerStoredPosition(url);
    print('gastube: system player resume stored ms=$ms helper=up');
  } else {
    if (fromFile == null || fromFile < _resumeMinMs) {
      await _writePlayerMs(wanted, ms);
    }
    print('gastube: system player resume stored ms=$ms helper=down');
  }
  return Duration(milliseconds: ms);
}

const _resumeMinMs = 5000;

/// Writes 0 for [url] so the player starts immediately and shows no dialog.
Future<void> clearSystemPlayerStoredPosition(String url) async {
  final file = await _systemPlayerSettingsFile();
  if (!file.existsSync()) return;
  final wanted = _playerSettingsKey(url);
  final next = _withoutStaleStreamKeys(
    file.readAsLinesSync().map((line) {
      final split = line.indexOf('=');
      if (split <= 0) return line;
      if (_unescapeIniKey(line.substring(0, split)) != wanted) return line;
      return '${line.substring(0, split)}=0';
    }).toList(),
    wanted,
  );
  await file.writeAsString('${next.join('\n')}\n');
}

/// `videoplayback?expire=...`, the key mediaplayer-app actually stores.
String _playerSettingsKey(String url) {
  final slash = url.lastIndexOf('/');
  if (slash < 0 || slash + 1 >= url.length) return url;
  return url.substring(slash + 1);
}

String _unescapeIniKey(String key) {
  final out = StringBuffer();
  for (var i = 0; i < key.length; i++) {
    final ch = key[i];
    if (ch == '\\') {
      out.write('/');
      continue;
    }
    if (ch == '%' && i + 2 < key.length) {
      final value = int.tryParse(key.substring(i + 1, i + 3), radix: 16);
      if (value != null) {
        out.writeCharCode(value);
        i += 2;
        continue;
      }
    }
    out.write(ch);
  }
  return out.toString();
}

Future<File> _systemPlayerSettingsFile() async {
  final root = await persistentAppDirectory();
  return File(p.join(root.path, 'player-resume', 'Media Player.conf'));
}

Future<File> _resumeDirFile(String name) async {
  final root = await persistentAppDirectory();
  return File(p.join(root.path, 'player-resume', name));
}

Future<int?> _storedMsForKey(String wanted) async {
  final file = await _systemPlayerSettingsFile();
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final split = line.indexOf('=');
    if (split <= 0) continue;
    if (_unescapeIniKey(line.substring(0, split)) != wanted) continue;
    return int.tryParse(line.substring(split + 1).trim());
  }
  return null;
}

Future<void> _writePlayerMs(String wanted, int ms) async {
  final file = await _systemPlayerSettingsFile();
  if (!file.existsSync()) return;
  var found = false;
  final next = file.readAsLinesSync().map((line) {
    final split = line.indexOf('=');
    if (split <= 0) return line;
    if (_unescapeIniKey(line.substring(0, split)) != wanted) return line;
    found = true;
    return '${line.substring(0, split)}=$ms';
  }).toList();
  if (!found) next.add('${_escapeIniKey(wanted)}=$ms');
  await file.writeAsString('${_withoutStaleStreamKeys(next, wanted).join('\n')}\n');
}

/// Muxed addresses put the whole query string in the key. The next extract
/// has a new `expire`, so the old line never matches again.
List<String> _withoutStaleStreamKeys(List<String> lines, String keep) {
  return lines.where((line) {
    final split = line.indexOf('=');
    if (split <= 0) return true;
    final key = _unescapeIniKey(line.substring(0, split));
    if (!key.startsWith('videoplayback?')) return true;
    return key == keep;
  }).toList();
}

String _escapeIniKey(String key) {
  final out = StringBuffer();
  for (final unit in key.codeUnits) {
    final ch = String.fromCharCode(unit);
    final alnum = (unit >= 0x30 && unit <= 0x39) ||
        (unit >= 0x41 && unit <= 0x5a) ||
        (unit >= 0x61 && unit <= 0x7a);
    if (alnum || ch == '_' || ch == '-' || ch == '.') {
      out.write(ch);
    } else if (ch == '/') {
      out.write(r'\');
    } else {
      out.write('%${unit.toRadixString(16).padLeft(2, '0').toUpperCase()}');
    }
  }
  return out.toString();
}

Future<int?> _rememberedMs(String wanted) async {
  final file = await _resumeDirFile('gastube-resume.txt');
  if (!file.existsSync()) return null;
  final lines = file.readAsLinesSync();
  if (lines.length < 2 || lines[1] != wanted) return null;
  return int.tryParse(lines.first.trim());
}

Future<void> _rememberMs(String wanted, int ms) async {
  final file = await _resumeDirFile('gastube-resume.txt');
  await file.parent.create(recursive: true);
  await file.writeAsString('$ms\n$wanted\n');
}

/// Tells the in-click helper which session to seek.
///
/// `ms` of 0 cancels a previous request.
Future<void> _writePendingSeek(int ms, String wanted) async {
  final file = await _resumeDirFile('pending-seek');
  final tmp = await _resumeDirFile('pending-seek.tmp');
  await tmp.parent.create(recursive: true);
  await tmp.writeAsString('$ms\n$wanted\n');
  await tmp.rename(file.path);
}

Future<bool> _seekHelperAlive() async {
  final file = await _resumeDirFile('seek-helper.heartbeat');
  if (!file.existsSync()) return false;
  final age = DateTime.now().difference(file.lastModifiedSync());
  return age < const Duration(seconds: 3);
}

/// Opens a finished download in Media Player.
///
/// The handoff is a temporary Content Hub link. It does not copy the file
/// into Music or Videos. Saving is the path that does that, and only once.
Future<({bool ok, String message})> openInSystemPlayer({
  required String path,
  required bool audioOnly,
}) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    const peer = 'mediaplayer-app';
    final state = await _chargeItem(
      client,
      hub,
      peer: peer,
      contentType: 'videos',
      name: p.basename(path),
      url: Uri.file(path).toString(),
    );
    if (state == 5) {
      print('gastube: open system failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: open system file=$path peer=$peer audio=$audioOnly state=$state');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: open system failed file=$path error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

/// Writes text onto the Lomiri pasteboard. Flutter's clipboard stays inside
/// this process, so other apps only see a paste that Content Hub stored.
Future<bool> copyToSystemPasteboard(String text) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    final reply = await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'CreatePaste',
      [
        DBusString(_appId()),
        const DBusString(''),
        DBusArray.byte(_pasteboardBytes(text)),
        DBusArray.string(const ['text/plain']),
      ],
      replySignature: DBusSignature('b'),
    );
    final ok = reply.returnValues.first.asBoolean();
    print('gastube: pasteboard ok=$ok bytes=${text.length}');
    return ok;
  } catch (error) {
    print('gastube: pasteboard failed error=$error');
    return false;
  } finally {
    await client.close();
  }
}

/// Content Hub stores the QtMir clipboard layout: little-endian int header,
/// then the format name, then the UTF-8 bytes.
List<int> _pasteboardBytes(String text) {
  final format = ascii.encode('text/plain');
  final data = utf8.encode(text);
  final header = 4 + 16;
  final bytes = Uint8List(header + format.length + data.length);
  final view = ByteData.sublistView(bytes);
  view.setInt32(0, 1, Endian.little);
  view.setInt32(4, header, Endian.little);
  view.setInt32(8, format.length, Endian.little);
  view.setInt32(12, header + format.length, Endian.little);
  view.setInt32(16, data.length, Endian.little);
  bytes.setRange(header, header + format.length, format);
  bytes.setRange(header + format.length, bytes.length, data);
  return bytes;
}

/// Hands a finished download to Gallery or Music so it leaves the click.
///
/// A second save sees the marker written next to the download and does not
/// charge again. The marker lives in the app directory, so this does not
/// read Music or Videos.
Future<({bool ok, String message})> exportDownload({
  required String path,
  required bool audioOnly,
  String title = '',
  String videoId = '',
}) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    final peer = audioOnly
        ? await _peerId(hub, 'KnownDestinationsForType', 'music', 'music.ubports_music')
        : await _peerId(hub, 'KnownDestinationsForType', 'videos', 'gallery.ubports_gallery');
    if (peer == null) {
      print('gastube: save hub failed file=$path error=no peer');
      return (ok: false, message: 'no peer');
    }
    final chargePath = await _aliasForCharge(
      sourcePath: path,
      title: title,
      videoId: videoId,
    );
    final wanted = _aliasName(chargePath);
    if (await _alreadySent(wanted)) {
      print('gastube: save hub reuse marker=$wanted');
      return (ok: true, message: '');
    }
    final type = audioOnly ? 'music' : 'videos';
    final state = await _chargeFile(
      client,
      hub,
      peer: peer,
      contentType: type,
      path: chargePath,
    );
    if (state != 5) await _markSent(wanted);
    if (state == 5) {
      print('gastube: save hub failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: save hub file=$chargePath peer=$peer type=$type state=$state');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: save hub failed file=$path error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

/// Sends a backup file to the file manager as a document.
Future<({bool ok, String message})> exportDocument(String path) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    final peer = await _peerId(
      hub,
      'KnownDestinationsForType',
      'documents',
      'filemanager.ubports_filemanager',
    );
    if (peer == null) {
      print('gastube: export document failed file=$path error=no peer');
      return (ok: false, message: 'no peer');
    }
    final state = await _chargeFile(
      client,
      hub,
      peer: peer,
      contentType: 'documents',
      path: path,
    );
    if (state == 5) {
      print('gastube: export document failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: export document file=$path peer=$peer state=$state');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: export document failed file=$path error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

/// Asks the file manager for one document and returns the copy Content Hub stored.
Future<({bool ok, String message, String? path})> importDocument() async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    final peer = await _peerId(
      hub,
      'KnownSourcesForType',
      'documents',
      'filemanager.ubports_filemanager',
    );
    if (peer == null) {
      print('gastube: import document failed error=no peer');
      return (ok: false, message: 'no peer', path: null);
    }
    final created = await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'CreateImportFromPeer',
      [DBusString(peer), DBusString(_appId()), const DBusString('documents')],
      replySignature: DBusSignature('o'),
    );
    final transfer = DBusRemoteObject(
      client,
      name: 'com.lomiri.content.dbus.Service',
      path: created.returnValues.first.asObjectPath(),
    );
    await transfer.callMethod('com.lomiri.content.dbus.Transfer', 'Start', const []);
    final state = await _waitForState(transfer);
    if (state != 3) {
      print('gastube: import document failed peer=$peer state=$state');
      return (ok: false, message: state == 5 ? 'cancelled' : 'state $state', path: null);
    }
    await transfer.callMethod(
      'com.lomiri.content.dbus.Transfer',
      'SetStore',
      [const DBusInt32(2), const DBusString('documents')],
      replySignature: DBusSignature('s'),
    );
    final collected = await transfer.callMethod(
      'com.lomiri.content.dbus.Transfer',
      'Collect',
      const [],
      replySignature: DBusSignature('av'),
    );
    final stored = _firstFilePath(collected.returnValues.first);
    if (stored == null) {
      print('gastube: import document failed peer=$peer error=empty store');
      return (ok: false, message: 'empty store', path: null);
    }
    print('gastube: import document file=$stored peer=$peer');
    return (ok: true, message: '', path: stored);
  } catch (error) {
    print('gastube: import document failed error=$error');
    return (ok: false, message: error.toString(), path: null);
  } finally {
    await client.close();
  }
}

/// Shares one text link with the system messaging app.
Future<({bool ok, String message})> shareText(String text) async {
  final client = DBusClient.session();
  try {
    final hub = _service(client);
    final peer = await _peerId(hub, 'KnownSharesForType', 'links', 'messaging-app');
    if (peer == null) {
      print('gastube: share text failed error=no peer');
      return (ok: false, message: 'no peer');
    }
    final created = await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'CreateShareToPeer',
      [DBusString(peer), DBusString(_appId()), const DBusString('links')],
      replySignature: DBusSignature('o'),
    );
    final transfer = DBusRemoteObject(
      client,
      name: 'com.lomiri.content.dbus.Service',
      path: created.returnValues.first.asObjectPath(),
    );
    final bytes = utf8.encode(text);
    await transfer.callMethod(
      'com.lomiri.content.dbus.Transfer',
      'Charge',
      [
        DBusArray(DBusSignature('v'), [
          DBusVariant(DBusStruct([
            const DBusString('text/plain'),
            DBusArray.byte(bytes),
            const DBusString('link'),
            DBusString(text),
          ])),
        ]),
      ],
    );
    print('gastube: share text peer=$peer');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: share text failed error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

/// Starts the resume helper that ships inside the click.
///
/// Lomiri stops this process group when the system player is in front.
/// The helper calls setsid, so it is not in that group and can seek after
/// the player is ready.
Future<void> startUbuntuTouchSeekHelper() async {
  if (!UbuntuTouch.enabled) return;
  final helper = p.join(p.dirname(Platform.resolvedExecutable), 'gastube-seek');
  if (!File(helper).existsSync()) {
    print('gastube: seek helper missing');
    return;
  }
  try {
    await Process.start(
      helper,
      const [],
      mode: ProcessStartMode.detached,
    );
    print('gastube: seek helper started');
  } catch (error) {
    print('gastube: seek helper start error=$error');
  }
}

/// Listens for a shared link or an imported document while the process lives.
Future<void> startUbuntuTouchContentHub() async {
  if (!UbuntuTouch.enabled) return;
  try {
    final client = DBusClient.session();
    final appId = _appId();
    final escaped = _dbusEscape(appId);
    final path = DBusObjectPath('/com/lomiri/content/handler/$escaped');
    await client.registerObject(_ContentHandler(path, client));
    await client.registerObject(
      _RunningUrlHandler(DBusObjectPath('/$escaped')),
    );
    print('gastube: url dbus path=/$escaped');
    await client.requestName('com.lomiri.content.handler.$escaped');
    final hub = _service(client);
    await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'RegisterImportExportHandler',
      [DBusString(appId), path],
    );
    await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'HandlerActive',
      [DBusString(appId)],
    );
    print('gastube: content handler registered id=$appId');
  } catch (error) {
    print('gastube: content handler failed error=$error');
  }
}

DBusRemoteObject _service(DBusClient client) {
  return DBusRemoteObject(
    client,
    name: 'com.lomiri.content.dbus.Service',
    path: DBusObjectPath('/'),
  );
}

String _appId() {
  final appId = Platform.environment['APP_ID'];
  if (appId != null && appId.isNotEmpty) return appId;
  return 'gastube.alphaliu01_gastube_0.9.4';
}

String _dbusEscape(String id) {
  return id.replaceAllMapped(RegExp(r'[^a-zA-Z0-9]'), (match) {
    final hex = match.group(0)!.codeUnitAt(0).toRadixString(16);
    return '_${hex.padLeft(2, '0')}';
  });
}

/// Hard link named with the video title. The Music app keeps the URL's last
/// component, so the charged path has to already carry that name.
Future<String> _aliasForCharge({
  required String sourcePath,
  required String title,
  required String videoId,
}) async {
  final names = Directory(p.join((await ubuntuTouchExportsDirectory()).path, 'names'));
  await names.create(recursive: true);
  final ext = p.extension(sourcePath);
  var base = _safeTitle(title);
  if (base.isEmpty) base = _safeTitle(p.basenameWithoutExtension(sourcePath));
  if (base.isEmpty) base = 'download';
  var fileName = '$base$ext';
  var dest = p.join(names.path, fileName);
  if (File(dest).existsSync() && !_sameInode(sourcePath, dest)) {
    final id = _safeTitle(videoId);
    if (id.isNotEmpty) {
      fileName = '$base $id$ext';
      dest = p.join(names.path, fileName);
    }
  }
  if (File(dest).existsSync()) {
    if (_sameInode(sourcePath, dest)) return dest;
    print('gastube: export alias occupied dest=$dest');
    return sourcePath;
  }
  if (_hardLink(sourcePath, dest)) return dest;
  return sourcePath;
}

String _aliasName(String path) => p.basename(path);

List<String> _exportFileNames({
  required String sourcePath,
  required String title,
  required String videoId,
}) {
  final ext = p.extension(sourcePath);
  var base = _safeTitle(title);
  if (base.isEmpty) base = _safeTitle(p.basenameWithoutExtension(sourcePath));
  if (base.isEmpty) base = 'download';
  final names = <String>['$base$ext'];
  final id = _safeTitle(videoId);
  if (id.isNotEmpty) names.add('$base $id$ext');
  final legacy = p.basename(sourcePath);
  if (legacy.isNotEmpty && !names.contains(legacy)) names.add(legacy);
  return names;
}

/// True when this download was already handed to Gallery or Music.
///
/// The marker is inside the app directory. The menu uses it to hide Save to
/// Device. It does not look in Music or Videos.
bool ubuntuTouchDeviceCopyExists({
  required String sourcePath,
  required String title,
  required String videoId,
}) {
  final root = _exportsRootSync();
  if (root == null) return false;
  for (final name in _exportFileNames(
    sourcePath: sourcePath,
    title: title,
    videoId: videoId,
  )) {
    if (File(p.join(root, 'sent', name)).existsSync()) return true;
  }
  return false;
}

String? _exportsRootSync() {
  final dataHome = Platform.environment['XDG_DATA_HOME'];
  final home = Platform.environment['HOME'] ?? '';
  final base = (dataHome != null && dataHome.isNotEmpty)
      ? dataHome
      : (home.isEmpty ? '' : p.join(home, '.local', 'share'));
  if (base.isEmpty) return null;
  return p.join(base, UbuntuTouch.clickPackage, 'Exports');
}

/// Drops the sandbox hard link created for a titled export.
///
/// The copy in Music or Videos stays. That file is the one the user saved.
Future<void> ubuntuTouchReleaseDownload({
  required String sourcePath,
  required String title,
  required String videoId,
}) async {
  final root = await ubuntuTouchExportsDirectory();
  final namesDir = Directory(p.join(root.path, 'names'));
  final sentDir = Directory(p.join(root.path, 'sent'));
  for (final name in _exportFileNames(
    sourcePath: sourcePath,
    title: title,
    videoId: videoId,
  )) {
    final alias = File(p.join(namesDir.path, name));
    if (!alias.existsSync() || !_sameInode(sourcePath, alias.path)) continue;
    alias.deleteSync();
    print('gastube: export alias removed file=${alias.path}');
    final marker = File(p.join(sentDir.path, name));
    if (marker.existsSync()) marker.deleteSync();
  }
}

String _safeTitle(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '')
      .replaceAll(RegExp(r'''[&,+()$~%'":*?<>{}]'''), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.length <= 80) return cleaned;
  return cleaned.substring(0, 80).trim();
}

bool _sameInode(String leftPath, String rightPath) {
  try {
    return FileSystemEntity.identicalSync(leftPath, rightPath);
  } catch (_) {
    return false;
  }
}

bool _hardLink(String source, String dest) {
  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final link = libc.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>),
        int Function(Pointer<Uint8>, Pointer<Uint8>)>('link');
    final malloc = libc.lookupFunction<
        Pointer<Uint8> Function(IntPtr),
        Pointer<Uint8> Function(int)>('malloc');
    final free = libc.lookupFunction<
        Void Function(Pointer<Uint8>),
        void Function(Pointer<Uint8>)>('free');
    final from = _nativePath(source, malloc);
    final to = _nativePath(dest, malloc);
    try {
      if (link(from, to) == 0) return true;
      print('gastube: export alias link failed source=$source dest=$dest');
      return false;
    } finally {
      free(from);
      free(to);
    }
  } catch (error) {
    print('gastube: export alias link failed error=$error');
    return false;
  }
}

Pointer<Uint8> _nativePath(
  String value,
  Pointer<Uint8> Function(int) malloc,
) {
  final units = utf8.encode(value);
  final pointer = malloc(units.length + 1);
  final bytes = pointer.asTypedList(units.length + 1);
  bytes.setRange(0, units.length, units);
  bytes[units.length] = 0;
  return pointer;
}

Future<File> _sentMarker(String fileName) async {
  final root = await ubuntuTouchExportsDirectory();
  final dir = Directory(p.join(root.path, 'sent'));
  await dir.create(recursive: true);
  return File(p.join(dir.path, fileName));
}

Future<void> _markSent(String fileName) async {
  final marker = await _sentMarker(fileName);
  if (!marker.existsSync()) marker.writeAsStringSync(fileName);
}

Future<bool> _alreadySent(String fileName) async {
  return (await _sentMarker(fileName)).existsSync();
}

Future<int> _chargeFile(
  DBusClient client,
  DBusRemoteObject hub, {
  required String peer,
  required String contentType,
  required String path,
}) {
  return _chargeItem(
    client,
    hub,
    peer: peer,
    contentType: contentType,
    name: p.basename(path),
    url: Uri.file(path).toString(),
  );
}

Future<int> _chargeItem(
  DBusClient client,
  DBusRemoteObject hub, {
  required String peer,
  required String contentType,
  required String name,
  required String url,
}) async {
  final created = await hub.callMethod(
    'com.lomiri.content.dbus.Service',
    'CreateExportToPeer',
    [DBusString(peer), DBusString(_appId()), DBusString(contentType)],
    replySignature: DBusSignature('o'),
  );
  final transfer = DBusRemoteObject(
    client,
    name: 'com.lomiri.content.dbus.Service',
    path: created.returnValues.first.asObjectPath(),
  );
  await transfer.callMethod(
    'com.lomiri.content.dbus.Transfer',
    'Charge',
    [
      DBusArray(DBusSignature('v'), [
        DBusVariant(DBusStruct([
          const DBusString(''),
          DBusArray.byte(<int>[]),
          DBusString(name),
          DBusString(url),
        ])),
      ]),
    ],
  );
  return _state(transfer);
}

Future<int> _state(DBusRemoteObject transfer) async {
  final reply = await transfer.callMethod(
    'com.lomiri.content.dbus.Transfer',
    'State',
    const [],
    replySignature: DBusSignature('i'),
  );
  return reply.returnValues.first.asInt32();
}

Future<int> _waitForState(DBusRemoteObject transfer) async {
  for (var i = 0; i < 360; i++) {
    final state = await _state(transfer);
    if (state == 3 || state == 4 || state == 5) return state;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return -1;
}

Future<String?> _peerId(
  DBusRemoteObject hub,
  String method,
  String type,
  String prefix,
) async {
  final reply = await hub.callMethod(
    'com.lomiri.content.dbus.Service',
    method,
    [DBusString(type)],
    replySignature: DBusSignature('av'),
  );
  final value = reply.returnValues.first;
  if (value is! DBusArray) return null;
  final ids = <String>[];
  for (final child in value.children) {
    final item = child is DBusVariant ? child.value : child;
    if (item is! DBusStruct || item.children.isEmpty) continue;
    final id = item.children.first;
    if (id is DBusString) ids.add(id.value);
  }
  for (final id in ids) {
    if (id.startsWith(prefix)) return id;
  }
  print('gastube: content peer missing type=$type prefix=$prefix ids=$ids');
  return null;
}

String? _firstFilePath(DBusValue value) {
  if (value is! DBusArray || value.children.isEmpty) return null;
  final first = value.children.first;
  final item = first is DBusVariant ? first.value : first;
  return _structFilePath(item);
}

String? _structFilePath(DBusValue item) {
  if (item is! DBusStruct || item.children.length < 4) return null;
  final url = item.children[3];
  if (url is! DBusString || url.value.isEmpty) return null;
  if (url.value.startsWith('file://')) return Uri.parse(url.value).toFilePath();
  if (url.value.startsWith('/')) return url.value;
  return null;
}

String? _structText(DBusValue item) {
  if (item is! DBusStruct || item.children.length < 4) return null;
  final url = item.children[3];
  if (url is DBusString && url.value.isNotEmpty) return url.value;
  final stream = item.children[1];
  if (stream is! DBusArray || stream.children.isEmpty) return null;
  final bytes = <int>[];
  for (final child in stream.children) {
    if (child is DBusByte) bytes.add(child.value);
  }
  if (bytes.isEmpty) return null;
  return utf8.decode(bytes, allowMalformed: true);
}

/// Lomiri sends a second link here when this process is already running.
/// The path is the app id with every punctuation character written as _xx.
class _RunningUrlHandler extends DBusObject {
  _RunningUrlHandler(super.path);

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'org.freedesktop.Application',
        methods: [
          DBusIntrospectMethod(
            'Open',
            args: [
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.in_,
                name: 'uris',
              ),
              DBusIntrospectArgument(
                DBusSignature('a{sv}'),
                DBusArgumentDirection.in_,
                name: 'platform_data',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.name != 'Open' || methodCall.values.isEmpty) {
      return DBusMethodSuccessResponse();
    }
    final uris = methodCall.values.first;
    if (uris is DBusArray) {
      for (final child in uris.children) {
        if (child is! DBusString || child.value.isEmpty) continue;
        print('gastube: url open ${child.value}');
        DeepLinkHandler().acceptSharedText(child.value);
      }
    }
    return DBusMethodSuccessResponse();
  }
}

class _ContentHandler extends DBusObject {
  _ContentHandler(super.path, this._client);

  final DBusClient _client;

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectMethod method(String name) {
      return DBusIntrospectMethod(
        name,
        args: [
          DBusIntrospectArgument(
            DBusSignature('o'),
            DBusArgumentDirection.in_,
            name: 'transfer',
          ),
        ],
      );
    }

    return [
      DBusIntrospectInterface(
        'com.lomiri.content.dbus.Handler',
        methods: [
          method('HandleImport'),
          method('HandleExport'),
          method('HandleShare'),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.values.isEmpty) return DBusMethodSuccessResponse();
    final objectPath = methodCall.values.first;
    if (objectPath is! DBusObjectPath) return DBusMethodSuccessResponse();
    print('gastube: content ${methodCall.name} path=${objectPath.value}');
    if (methodCall.name == 'HandleShare' || methodCall.name == 'HandleImport') {
      unawaited(_take(objectPath, methodCall.name));
    }
    return DBusMethodSuccessResponse();
  }

  Future<void> _take(DBusObjectPath objectPath, String method) async {
    try {
      final transfer = DBusRemoteObject(
        _client,
        name: 'com.lomiri.content.dbus.Service',
        path: objectPath,
      );
      if (method == 'HandleImport') {
        await transfer.callMethod(
          'com.lomiri.content.dbus.Transfer',
          'SetStore',
          [const DBusInt32(2), const DBusString('documents')],
          replySignature: DBusSignature('s'),
        );
      }
      final collected = await transfer.callMethod(
        'com.lomiri.content.dbus.Transfer',
        'Collect',
        const [],
        replySignature: DBusSignature('av'),
      );
      final value = collected.returnValues.first;
      if (value is! DBusArray) return;
      for (final child in value.children) {
        final item = child is DBusVariant ? child.value : child;
        final filePath = _structFilePath(item);
        final text = _structText(item);
        print('gastube: content $method file=$filePath text=$text');
        if (text != null && text.isNotEmpty) {
          DeepLinkHandler().acceptSharedText(text);
        }
      }
    } catch (error) {
      print('gastube: content $method failed error=$error');
    }
  }
}

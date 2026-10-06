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

/// Opens a finished download in the system app for that kind of file.
///
/// Video goes to Media Player. A fresh `video://` launch leaves that player
/// without a source, so video still uses one Content Hub charge. Audio goes to
/// the Music app, which copies every charge into `~/Music/Imported` under a
/// new time prefix. A later open of the same audio plays the copy already
/// there.
Future<({bool ok, String message})> openInSystemPlayer({
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
        : 'mediaplayer-app';
    if (peer == null) {
      print('gastube: open system failed file=$path error=no music peer');
      return (ok: false, message: 'no music peer');
    }
    if (audioOnly) {
      final reused = await _reuseAudio(
        sourcePath: path,
        title: title,
        videoId: videoId,
        package: peer,
      );
      if (reused != null) return reused;
    }
    final chargePath = audioOnly
        ? await _aliasForCharge(sourcePath: path, title: title, videoId: videoId)
        : path;
    final state = await _chargeFile(
      client,
      hub,
      peer: peer,
      contentType: audioOnly ? 'music' : 'videos',
      path: chargePath,
    );
    if (audioOnly && state != 5) {
      await _markSent(_aliasName(chargePath));
    }
    if (state == 5) {
      print('gastube: open system failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: open system file=$chargePath peer=$peer state=$state');
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
/// The file handed over is named from [title]. A second save of the same
/// download finds that copy and does not charge again.
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
    final existing = _findSystemCopy(
      audioOnly: audioOnly,
      wantedName: wanted,
      legacyName: '',
    );
    if (existing != null) {
      print('gastube: save hub reuse file=${existing.path}');
      return (ok: true, message: '');
    }
    if (await _alreadySent(wanted)) {
      final waited = await _waitForCopy(
        audioOnly: audioOnly,
        wantedName: wanted,
        legacyName: '',
      );
      if (waited != null) {
        print('gastube: save hub reuse file=${waited.path}');
        return (ok: true, message: '');
      }
      final marker = await _sentMarker(wanted);
      if (marker.existsSync()) marker.deleteSync();
      print('gastube: save hub retry file=$path reason=previous copy missing');
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

/// Plays an audio file the Music app already imported, instead of charging
/// another copy into `~/Music/Imported`.
Future<({bool ok, String message})?> _reuseAudio({
  required String sourcePath,
  required String title,
  required String videoId,
  required String package,
}) async {
  final chargePath = await _aliasForCharge(
    sourcePath: sourcePath,
    title: title,
    videoId: videoId,
  );
  final wanted = _aliasName(chargePath);
  final legacy = p.basename(sourcePath);
  final legacyName = legacy == wanted ? '' : legacy;
  final found = _findSystemCopy(
    audioOnly: true,
    wantedName: wanted,
    legacyName: legacyName,
  );
  if (found != null) return _dispatchMusic(found.path, package);
  if (!await _alreadySent(wanted)) return null;
  final waited = await _waitForCopy(
    audioOnly: true,
    wantedName: wanted,
    legacyName: legacyName,
  );
  if (waited != null) return _dispatchMusic(waited.path, package);
  print('gastube: open system reuse failed file=$sourcePath error=copy still missing');
  return (ok: false, message: 'copy still missing');
}

/// Click ids are `package_app_version`. The dispatcher compares the package
/// only. The full id makes it refuse the URL, so the saved file never opens.
String _clickPackage(String appId) {
  final split = appId.split('_');
  if (split.length >= 3 && split.first.isNotEmpty) return split.first;
  return appId;
}

Future<({bool ok, String message})> _dispatchMusic(String path, String package) async {
  final client = DBusClient.session();
  try {
    final url = Uri.file(path).toString().replaceFirst('file://', 'music://');
    final dispatcher = DBusRemoteObject(
      client,
      name: 'com.lomiri.URLDispatcher',
      path: DBusObjectPath('/com/lomiri/URLDispatcher'),
    );
    await dispatcher.callMethod(
      'com.lomiri.URLDispatcher',
      'DispatchURL',
      [DBusString(url), DBusString(_clickPackage(package))],
    );
    print('gastube: open system reuse file=$path');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: open system reuse failed file=$path error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
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

/// True when Gallery or Music already has this download.
///
/// The downloads menu uses this to stop offering Save to Device again.
bool ubuntuTouchDeviceCopyExists({
  required String sourcePath,
  required bool audioOnly,
  required String title,
  required String videoId,
}) {
  for (final name in _exportFileNames(
    sourcePath: sourcePath,
    title: title,
    videoId: videoId,
  )) {
    if (_findSystemCopy(audioOnly: audioOnly, wantedName: name, legacyName: '') !=
        null) {
      return true;
    }
  }
  return false;
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

File? _findSystemCopy({
  required bool audioOnly,
  required String wantedName,
  required String legacyName,
}) {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty || wantedName.isEmpty) return null;
  final roots = audioOnly
      ? [Directory(p.join(home, 'Music', 'Imported'))]
      : [
          Directory(p.join(home, 'Videos', 'imported')),
          Directory(p.join(home, 'Videos', 'Imported')),
        ];
  File? titled;
  File? legacy;
  for (final root in roots) {
    if (!root.existsSync()) continue;
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (_importNameMatches(name, wantedName)) {
          titled ??= entity;
        } else if (legacyName.isNotEmpty && _importNameMatches(name, legacyName)) {
          legacy ??= entity;
        }
      }
    } catch (error) {
      print('gastube: import lookup failed dir=${root.path} error=$error');
    }
  }
  return titled ?? legacy;
}

bool _importNameMatches(String name, String wanted) {
  if (wanted.isEmpty) return false;
  if (name == wanted) return true;
  return RegExp('^(?:\\d{6}-)+${RegExp.escape(wanted)}\$').hasMatch(name);
}

Future<File?> _waitForCopy({
  required bool audioOnly,
  required String wantedName,
  required String legacyName,
}) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final found = _findSystemCopy(
      audioOnly: audioOnly,
      wantedName: wantedName,
      legacyName: legacyName,
    );
    if (found != null) return found;
  }
  return null;
}

Future<int> _chargeFile(
  DBusClient client,
  DBusRemoteObject hub, {
  required String peer,
  required String contentType,
  required String path,
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
          DBusString(p.basename(path)),
          DBusString(Uri.file(path).toString()),
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

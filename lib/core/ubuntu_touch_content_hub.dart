import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:fluxtube/core/deep_link_handler.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:path/path.dart' as p;

/// Opens a finished download in the system app for that kind of file.
///
/// Video goes to Media Player. Audio goes to the Music app. Charge leaves the
/// transfer charged so that app can take the copy. Collecting here, or opening
/// a video:// URL ourselves, makes Media Player ask for a file.
Future<({bool ok, String message})> openInSystemPlayer({
  required String path,
  required bool audioOnly,
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
    final state = await _chargeFile(
      client,
      hub,
      peer: peer,
      contentType: audioOnly ? 'music' : 'videos',
      path: path,
    );
    if (state == 5) {
      print('gastube: open system failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: open system file=$path peer=$peer state=$state');
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
Future<({bool ok, String message})> exportDownload({
  required String path,
  required bool audioOnly,
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
    final type = audioOnly ? 'music' : 'videos';
    final state = await _chargeFile(client, hub, peer: peer, contentType: type, path: path);
    if (state == 5) {
      print('gastube: save hub failed file=$path peer=$peer error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: save hub file=$path peer=$peer type=$type state=$state');
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

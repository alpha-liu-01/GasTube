import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:path/path.dart' as p;

/// Copies a finished download into the system player and lets that player open it.
///
/// Charge leaves the transfer charged. Content Hub then starts Media Player and
/// hands it the copy. Collecting here, or opening a video:// URL ourselves,
/// starts the player with an empty source, and it asks the user to pick a file.
/// Desktop builds do not call this.
Future<({bool ok, String message})> openInSystemPlayer({
  required String path,
  required bool audioOnly,
}) async {
  final client = DBusClient.session();
  try {
    final appId = Platform.environment['APP_ID'];
    final source = (appId != null && appId.isNotEmpty)
        ? appId
        : 'gastube.alphaliu01_gastube_0.9.3';
    const peer = 'mediaplayer-app';
    final contentType = audioOnly ? 'music' : 'videos';
    final hub = DBusRemoteObject(
      client,
      name: 'com.lomiri.content.dbus.Service',
      path: DBusObjectPath('/'),
    );
    final created = await hub.callMethod(
      'com.lomiri.content.dbus.Service',
      'CreateExportToPeer',
      [
        const DBusString(peer),
        DBusString(source),
        DBusString(contentType),
      ],
      replySignature: DBusSignature('o'),
    );
    final transferPath = created.returnValues.first.asObjectPath();
    final transfer = DBusRemoteObject(
      client,
      name: 'com.lomiri.content.dbus.Service',
      path: transferPath,
    );
    final uri = Uri.file(path).toString();
    await transfer.callMethod(
      'com.lomiri.content.dbus.Transfer',
      'Charge',
      [
        DBusArray(DBusSignature('v'), [
          DBusVariant(DBusStruct([
            const DBusString(''),
            DBusArray.byte(<int>[]),
            DBusString(p.basename(path)),
            DBusString(uri),
          ])),
        ]),
      ],
    );
    final stateReply = await transfer.callMethod(
      'com.lomiri.content.dbus.Transfer',
      'State',
      const [],
      replySignature: DBusSignature('i'),
    );
    final state = stateReply.returnValues.first.asInt32();
    if (state == 5) {
      print('gastube: open system failed file=$path error=aborted');
      return (ok: false, message: 'aborted');
    }
    print('gastube: open system file=$path state=$state');
    return (ok: true, message: '');
  } catch (error) {
    print('gastube: open system failed file=$path error=$error');
    return (ok: false, message: error.toString());
  } finally {
    await client.close();
  }
}

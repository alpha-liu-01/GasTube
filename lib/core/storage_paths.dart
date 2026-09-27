import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Directory that is still there after the app exits.
///
/// On a normal Linux desktop this is `$XDG_DATA_HOME/<app id>`
/// (`~/.local/share/...`). Inside Flatpak, `xdg-user-dir DOCUMENTS` is the
/// sandbox home, and that home is discarded when the process exits.
/// `$XDG_DATA_HOME` is the per-app directory Flatpak keeps.
Future<Directory> persistentAppDirectory() {
  return getApplicationSupportDirectory();
}

/// Copy [name] out of the old Documents location into [destination] once.
///
/// Desktop builds wrote the database and playlists next to the user's
/// documents. A missing file, or a Documents directory the sandbox cannot
/// read, leaves [destination] untouched.
Future<void> copyLegacyDocumentFile(String name, File destination) async {
  if (await destination.exists()) return;
  final Directory docs;
  try {
    docs = await getApplicationDocumentsDirectory();
  } catch (_) {
    return;
  }
  final legacy = File(p.join(docs.path, name));
  if (!await legacy.exists()) return;
  try {
    await destination.parent.create(recursive: true);
    await legacy.copy(destination.path);
  } catch (_) {}
}

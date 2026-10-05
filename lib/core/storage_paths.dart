import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ubuntu_touch.dart';

/// Directory that is still there after the app exits.
///
/// On a normal Linux desktop this is `$XDG_DATA_HOME/<app id>`
/// (`~/.local/share/...`). Inside Flatpak, `xdg-user-dir DOCUMENTS` is the
/// sandbox home, and that home is discarded when the process exits.
/// `$XDG_DATA_HOME` is the per-app directory Flatpak keeps.
Future<Directory> persistentAppDirectory() async {
  if (UbuntuTouch.enabled) {
    final dataHome = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'] ?? '';
    final base = (dataHome != null && dataHome.isNotEmpty)
        ? dataHome
        : p.join(home, '.local', 'share');
    final dir = Directory(p.join(base, UbuntuTouch.clickPackage));
    await dir.create(recursive: true);
    return dir;
  }
  return getApplicationSupportDirectory();
}

/// Exported and copied files that stay inside the app until Content Hub.
///
/// Call this on Ubuntu Touch. The directory is under
/// `persistentAppDirectory()`, which confinement can write.
Future<Directory> ubuntuTouchExportsDirectory() async {
  final root = await persistentAppDirectory();
  final dir = Directory(p.join(root.path, 'Exports'));
  await dir.create(recursive: true);
  return dir;
}

/// Copy [name] out of the old Documents location into [destination] once.
///
/// Desktop builds wrote the database and playlists next to the user's
/// documents. A missing file, or a Documents directory the sandbox cannot
/// read, leaves [destination] untouched.
Future<void> copyLegacyDocumentFile(String name, File destination) async {
  if (UbuntuTouch.enabled) return;
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

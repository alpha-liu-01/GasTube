import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;

import 'ubuntu_touch.dart';

/// Point cover caching at the Click package directory.
///
/// path_provider names its directory after the executable, `gastube`. The
/// Click confinement allows `~/.cache/gastube.alphaliu01/` and rejects the
/// executable name. Desktop builds leave the default cache manager in place.
void installUbuntuTouchImageCache() {
  if (!UbuntuTouch.enabled) return;
  CachedNetworkImageProvider.defaultCacheManager = _ClickImageCache();
}

class _ClickImageCache extends CacheManager with ImageCacheManager {
  _ClickImageCache() : super(_config());

  static Config _config() {
    const key = 'libCachedImageData';
    final root = _cacheRoot();
    return Config(
      key,
      repo: JsonCacheInfoRepository(path: p.join(root, '$key.json')),
      fileSystem: _ClickCacheFiles(io.Directory(p.join(root, key))),
    );
  }

  static String _cacheRoot() {
    final cacheHome = io.Platform.environment['XDG_CACHE_HOME'];
    final home = io.Platform.environment['HOME'] ?? '';
    final base = (cacheHome != null && cacheHome.isNotEmpty)
        ? cacheHome
        : p.join(home, '.cache');
    return p.join(base, UbuntuTouch.clickPackage);
  }
}

class _ClickCacheFiles implements FileSystem {
  _ClickCacheFiles(this._directory);

  final io.Directory _directory;
  static const LocalFileSystem _files = LocalFileSystem();

  @override
  Future<File> createFile(String name) async {
    if (!_directory.existsSync()) {
      _directory.createSync(recursive: true);
    }
    return _files.directory(_directory.path).childFile(name);
  }
}

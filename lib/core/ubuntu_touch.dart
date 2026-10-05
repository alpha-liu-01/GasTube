/// Set only by the Ubuntu Touch release build:
/// `--dart-define=GASTUBE_UBUNTU_TOUCH=true`.
/// Desktop, Flatpak, deb, and rpm builds leave it false.
class UbuntuTouch {
  static const bool enabled = bool.fromEnvironment('GASTUBE_UBUNTU_TOUCH');

  /// Click package name. AppArmor allows writes under
  /// `~/.local/share/<this>/`, not under the executable name.
  static const String clickPackage = 'gastube.alphaliu01';
}

/// URLs Lomiri put on the command line of this process.
class UbuntuTouchUrls {
  static final List<String> argv = [];

  /// https links, plus the Android intent URL the mobile YouTube page uses
  /// for its Open app button.
  static bool isLaunchArgument(String arg) {
    return arg.startsWith('https://') ||
        arg.startsWith('http://') ||
        arg.startsWith('intent://') ||
        arg.startsWith('vnd.youtube:') ||
        arg.startsWith('youtube:');
  }
}

/// Set only by the Ubuntu Touch release build:
/// `--dart-define=GASTUBE_UBUNTU_TOUCH=true`.
/// Desktop, Flatpak, deb, and rpm builds leave it false.
class UbuntuTouch {
  static const bool enabled = bool.fromEnvironment('GASTUBE_UBUNTU_TOUCH');

  /// Click package name. AppArmor allows writes under
  /// `~/.local/share/<this>/`, not under the executable name.
  static const String clickPackage = 'gastube.alphaliu01';
}

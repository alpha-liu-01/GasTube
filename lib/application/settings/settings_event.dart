part of 'settings_bloc.dart';

@freezed
class SettingsEvent with _$SettingsEvent {
  factory SettingsEvent.initializeSettings() = InitializeSettings;
  factory SettingsEvent.getDefaultLanguage({required String? language}) =
      GetDefaultLanguage;
  factory SettingsEvent.getDefaultQuality({required String? quality}) =
      GetDefaultQuality;
  factory SettingsEvent.getDefaultRegion({required String? region}) =
      GetDefaultRegion;
  factory SettingsEvent.changeTheme({required String themeMode}) = ChangeTheme;
  factory SettingsEvent.toggleHistoryVisibility() = ToggleHistoryVisibility;
  factory SettingsEvent.toggleDislikeVisibility() = ToggleDislikeVisibility;
  factory SettingsEvent.toggleHlsPlayer() = ToggleHlsPlayer;
  factory SettingsEvent.toggleCommentVisibility() = ToggleCommentVisibility;
  factory SettingsEvent.toggleRelatedVideoVisibility() =
      ToggleRelatedVideoVisibility;
  factory SettingsEvent.fetchPipedInstances({@Default(false) bool forceRefresh}) = FetchPipedInstances;
  factory SettingsEvent.fetchInvidiousInstances({@Default(false) bool forceRefresh}) = FetchInvidiousInstances;
  factory SettingsEvent.setInstance({required String instanceApi}) =
      SetInstance;
  factory SettingsEvent.setYTService({required YouTubeServices service}) =
      SetYTService;
  factory SettingsEvent.togglePipPlayer() = TogglePipPlayer;
  // New events for additional features
  factory SettingsEvent.setSearchFilter({required String filter}) =
      SetSearchFilter;
  factory SettingsEvent.setVideoFitMode({required String fitMode}) =
      SetVideoFitMode;
  factory SettingsEvent.setDefaultVideoCodec({required String codec}) =
      SetDefaultVideoCodec;
  factory SettingsEvent.setSkipInterval({required int seconds}) =
      SetSkipInterval;
  factory SettingsEvent.toggleSponsorBlock() = ToggleSponsorBlock;
  factory SettingsEvent.setSponsorBlockCategories(
      {required List<String> categories}) = SetSponsorBlockCategories;
  factory SettingsEvent.toggleOpenLinksInBrowser() = ToggleOpenLinksInBrowser;
  factory SettingsEvent.setHomeFeedMode({required String mode}) = SetHomeFeedMode;
  factory SettingsEvent.toggleAudioFocus() = ToggleAudioFocus;
  // Profile events
  factory SettingsEvent.addProfile({required String profileName}) = AddProfile;
  factory SettingsEvent.deleteProfile({required String profileName}) =
      DeleteProfile;
  factory SettingsEvent.switchProfile({required String profileName}) =
      SwitchProfile;
  factory SettingsEvent.renameProfile({required String oldName, required String newName}) =
      RenameProfile;
  // Import/Export events
  factory SettingsEvent.exportSubscriptions({@Default('default') String profileName}) = ExportSubscriptions;
  factory SettingsEvent.importSubscriptions({required String filePath, @Default('default') String profileName}) =
      ImportSubscriptions;
  // Subtitle size
  factory SettingsEvent.setSubtitleSize({required double size}) = SetSubtitleSize;
  // Search history privacy
  factory SettingsEvent.toggleSearchHistoryEnabled() = ToggleSearchHistoryEnabled;
  factory SettingsEvent.toggleSearchHistoryVisibility() = ToggleSearchHistoryVisibility;
  // Set last exported file path (for share functionality)
  factory SettingsEvent.setLastExportedFilePath({required String filePath}) = SetLastExportedFilePath;
  // Auto PiP toggle
  factory SettingsEvent.toggleAutoPip() = ToggleAutoPip;
}

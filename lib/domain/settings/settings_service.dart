import 'package:dartz/dartz.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/domain/settings/models/instance.dart';

abstract class SettingsService {
  Future<List<Map<String, String>>> initializeSettings();
  Future<Either<MainFailure, String>> selectDefaultLanguage(
      {required String language});
  Future<Either<MainFailure, String>> selectDefaultQuality(
      {required String quality});
  Future<Either<MainFailure, String>> selectRegion({required String region});
  Future<Either<MainFailure, String>> setTheme({required String themeMode});
  Future<Either<MainFailure, bool>> toggleHistoryVisibility(
      {required bool isHistoryVisible});
  Future<Either<MainFailure, bool>> toggleDislikeVisibility(
      {required bool isDislikeVisible});
  Future<Either<MainFailure, bool>> toggleHlsPlayer(
      {required bool isHlsPlayer});
  Future<Either<MainFailure, bool>> toggleHideComments(
      {required bool isHideComments});
  Future<Either<MainFailure, bool>> toggleHideRelatedVideos(
      {required bool isHideRelated});
  Future<Either<MainFailure, List<Instance>>> fetchInstances();
  Future<Either<MainFailure, List<Instance>>> fetchInvidiousInstances();
  Future<Either<MainFailure, String>> setInstance(
      {required String instanceApi});
  Future<Either<MainFailure, YouTubeServices>> setTYService(
      {required YouTubeServices service});
  Future<Either<MainFailure, bool>> togglePipPlayer(
      {required bool isPipDisabled});
  Future<Either<MainFailure, String>> findWorkingPipedInstance({
    required List<Instance> instances,
    String? preferredInstanceApi,
    void Function(String instanceName)? onTestingInstance,
  });
  Future<bool> testInstanceConnection(String apiUrl);
  Future<Either<MainFailure, String>> findWorkingInvidiousInstance({
    required List<Instance> instances,
    String? preferredInstanceApi,
    void Function(String instanceName)? onTestingInstance,
  });
  Future<bool> testInvidiousInstanceConnection(String apiUrl);
  // New methods for additional features
  Future<Either<MainFailure, String>> setSearchFilter({required String filter});
  Future<Either<MainFailure, String>> setVideoFitMode({required String fitMode});
  Future<Either<MainFailure, String>> setDefaultVideoCodec(
      {required String codec});
  Future<Either<MainFailure, int>> setSkipInterval({required int seconds});
  Future<Either<MainFailure, bool>> toggleSponsorBlock({required bool isEnabled});
  Future<Either<MainFailure, List<String>>> setSponsorBlockCategories(
      {required List<String> categories});
  Future<Either<MainFailure, bool>> toggleOpenLinksInBrowser(
      {required bool openInBrowser});
  Future<Either<MainFailure, String>> setHomeFeedMode({required String mode});
  Future<Either<MainFailure, bool>> toggleAudioFocus({required bool isEnabled});
  // Profile methods
  Future<Either<MainFailure, List<String>>> addProfile({required String profileName});
  Future<Either<MainFailure, List<String>>> deleteProfile({required String profileName});
  Future<Either<MainFailure, String>> switchProfile({required String profileName});
  Future<Either<MainFailure, List<String>>> renameProfile({required String oldName, required String newName});
  Future<Either<MainFailure, List<String>>> getProfiles();
  // Import/Export methods
  Future<Either<MainFailure, String>> exportSubscriptions({String profileName = 'default'});
  Future<Either<MainFailure, int>> importSubscriptions({required String filePath, String profileName = 'default'});
  // Subtitle size
  Future<Either<MainFailure, double>> setSubtitleSize({required double size});
  // Search history privacy
  Future<Either<MainFailure, bool>> toggleSearchHistoryEnabled({required bool isEnabled});
  Future<Either<MainFailure, bool>> toggleSearchHistoryVisibility({required bool isVisible});
  // Auto PiP
  Future<Either<MainFailure, bool>> toggleAutoPip({required bool isEnabled});
}

part of 'download_bloc.dart';

@freezed
class DownloadEvent with _$DownloadEvent {
  /// Get available download options for a video (uses youtube_explode_dart - may fail with 403)
  const factory DownloadEvent.getDownloadOptions({
    required String videoId,
    required String serviceType,
  }) = _GetDownloadOptions;

  /// Set download options from NewPipe streams (uses already fetched video data - more reliable)
  const factory DownloadEvent.setDownloadOptionsFromStreams({
    required String videoId,
    required String title,
    required String channelName,
    String? thumbnailUrl,
    int? duration,
    required List<NewPipeVideoStream> videoStreams,
    required List<NewPipeVideoStream> videoOnlyStreams,
    required List<NewPipeAudioStream> audioStreams,
    @Default(defaultVideoCodecH264) String preferredCodec,
  }) = _SetDownloadOptionsFromStreams;

  /// Start a new download
  const factory DownloadEvent.startDownload({
    required String videoId,
    required String title,
    required String channelName,
    required DownloadType downloadType,
    @Default('default') String profileName,
    String? thumbnailUrl,
    int? duration,
    VideoQualityOption? videoQuality,
    AudioQualityOption? audioQuality,
  }) = _StartDownload;

  /// Pause an active download
  const factory DownloadEvent.pauseDownload({
    required int downloadId,
  }) = _PauseDownload;

  /// Resume a paused download
  const factory DownloadEvent.resumeDownload({
    required int downloadId,
  }) = _ResumeDownload;

  /// Cancel a download
  const factory DownloadEvent.cancelDownload({
    required int downloadId,
  }) = _CancelDownload;

  /// Delete a download and its files
  const factory DownloadEvent.deleteDownload({
    required int downloadId,
  }) = _DeleteDownload;

  /// Get all downloads
  const factory DownloadEvent.getAllDownloads({
    @Default('default') String profileName,
  }) = _GetAllDownloads;

  /// Update download progress (internal)
  const factory DownloadEvent.updateDownloadProgress({
    required DownloadItem downloadItem,
  }) = _UpdateDownloadProgress;

  /// Download completed (internal)
  const factory DownloadEvent.downloadCompleted({
    required DownloadItem downloadItem,
  }) = _DownloadCompleted;

  /// Download failed (internal)
  const factory DownloadEvent.downloadFailed({
    required DownloadItem downloadItem,
    required String error,
  }) = _DownloadFailed;

  /// Clear download options
  const factory DownloadEvent.clearDownloadOptions() = _ClearDownloadOptions;

  /// Save downloaded file to device storage (gallery/downloads)
  const factory DownloadEvent.saveToDevice({
    required DownloadItem downloadItem,
  }) = _SaveToDevice;
}

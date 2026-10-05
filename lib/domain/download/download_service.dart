import 'package:dartz/dartz.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/domain/download/models/download_item.dart';
import 'package:fluxtube/domain/download/models/download_quality.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_stream.dart';

/// Abstract service for download operations
abstract class DownloadService {
  /// Get available download options for a video
  Future<Either<MainFailure, DownloadOptions>> getDownloadOptions({
    required String videoId,
    required String serviceType,
  });

  /// Get download options from NewPipe streams (uses already fetched video data)
  DownloadOptions getDownloadOptionsFromStreams({
    required String videoId,
    required String title,
    required String channelName,
    String? thumbnailUrl,
    int? duration,
    List<NewPipeVideoStream>? videoStreams,
    List<NewPipeVideoStream>? videoOnlyStreams,
    List<NewPipeAudioStream>? audioStreams,
    String preferredCodec = defaultVideoCodecH264,
  });

  /// Start a download
  Future<Either<MainFailure, DownloadItem>> startDownload({
    required DownloadItem item,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(DownloadItem, String) onError,
  });

  /// Pause a download
  Future<Either<MainFailure, Unit>> pauseDownload(int downloadId);

  /// Resume a paused download
  Future<Either<MainFailure, DownloadItem>> resumeDownload({
    required int downloadId,
    required Function(DownloadItem) onProgress,
    required Function(DownloadItem) onComplete,
    required Function(DownloadItem, String) onError,
  });

  /// Cancel a download
  Future<Either<MainFailure, Unit>> cancelDownload(int downloadId);

  /// Delete a downloaded file
  Future<Either<MainFailure, Unit>> deleteDownload(int downloadId);

  /// Get all downloads
  Future<Either<MainFailure, List<DownloadItem>>> getAllDownloads({
    String profileName = 'default',
  });

  /// Get downloads by status
  Future<Either<MainFailure, List<DownloadItem>>> getDownloadsByStatus({
    required DownloadStatus status,
    String profileName = 'default',
  });

  /// Get active downloads count
  Future<int> getActiveDownloadsCount();

  /// Check if a video is already downloaded
  Future<bool> isVideoDownloaded(String videoId, {String profileName = 'default'});

  /// Get downloaded file path for a video
  Future<String?> getDownloadedFilePath(String videoId, {String profileName = 'default'});

  /// Clean up incomplete downloads
  Future<void> cleanupIncompleteDownloads();

  /// Save downloaded file to device storage (gallery/downloads folder)
  /// This makes the file visible in file managers and media apps
  Future<Either<MainFailure, Unit>> saveToDevice(DownloadItem item);
}

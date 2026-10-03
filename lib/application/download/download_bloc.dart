import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/domain/download/download_service.dart';
import 'package:fluxtube/domain/download/models/download_item.dart';
import 'package:fluxtube/domain/download/models/download_quality.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_stream.dart';
import 'package:fluxtube/infrastructure/download/download_notification_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/settings.dart';

part 'download_event.dart';
part 'download_state.dart';
part 'download_bloc.freezed.dart';

@injectable
class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final DownloadService _downloadService;
  final DownloadNotificationService _notificationService = DownloadNotificationService();

  // Track last notification update time to throttle updates
  final Map<int, DateTime> _lastNotificationUpdate = {};
  static const _notificationThrottleDuration = Duration(milliseconds: 1000);

  DownloadBloc(this._downloadService) : super(DownloadState.initial()) {
    // Initialize notification service
    _initNotifications();
    on<_GetDownloadOptions>(_onGetDownloadOptions);
    on<_SetDownloadOptionsFromStreams>(_onSetDownloadOptionsFromStreams);
    on<_StartDownload>(_onStartDownload);
    on<_PauseDownload>(_onPauseDownload);
    on<_ResumeDownload>(_onResumeDownload);
    on<_CancelDownload>(_onCancelDownload);
    on<_DeleteDownload>(_onDeleteDownload);
    on<_GetAllDownloads>(_onGetAllDownloads);
    on<_UpdateDownloadProgress>(_onUpdateDownloadProgress);
    on<_DownloadCompleted>(_onDownloadCompleted);
    on<_DownloadFailed>(_onDownloadFailed);
    on<_ClearDownloadOptions>(_onClearDownloadOptions);
    on<_SaveToDevice>(_onSaveToDevice);
  }

  Future<void> _initNotifications() async {
    try {
      final success = await _notificationService.initialize();
      if (!success) {
        // ignore: avoid_print
        print('[DownloadBloc] Notification service failed to initialize');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DownloadBloc] Notification init error: $e');
    }
  }

  Future<void> _onGetDownloadOptions(
    _GetDownloadOptions event,
    Emitter<DownloadState> emit,
  ) async {
    emit(state.copyWith(
      fetchOptionsStatus: ApiStatus.loading,
      downloadOptions: null,
    ));

    final result = await _downloadService.getDownloadOptions(
      videoId: event.videoId,
      serviceType: event.serviceType,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        fetchOptionsStatus: ApiStatus.error,
        errorMessage: failure.toString(),
      )),
      (options) => emit(state.copyWith(
        fetchOptionsStatus: ApiStatus.loaded,
        downloadOptions: options,
      )),
    );
  }

  void _onSetDownloadOptionsFromStreams(
    _SetDownloadOptionsFromStreams event,
    Emitter<DownloadState> emit,
  ) {
    emit(state.copyWith(
      fetchOptionsStatus: ApiStatus.loading,
      downloadOptions: null,
    ));

    final options = _downloadService.getDownloadOptionsFromStreams(
      videoId: event.videoId,
      title: event.title,
      channelName: event.channelName,
      thumbnailUrl: event.thumbnailUrl,
      duration: event.duration,
      videoStreams: event.videoStreams,
      videoOnlyStreams: event.videoOnlyStreams,
      audioStreams: event.audioStreams,
      preferredCodec: event.preferredCodec,
    );

    emit(state.copyWith(
      fetchOptionsStatus: ApiStatus.loaded,
      downloadOptions: options,
    ));
  }

  Future<void> _onStartDownload(
    _StartDownload event,
    Emitter<DownloadState> emit,
  ) async {
    // Create download item
    final item = DownloadItem.create(
      videoId: event.videoId,
      title: event.title,
      channelName: event.channelName,
      downloadType: event.downloadType,
      profileName: event.profileName,
      thumbnailUrl: event.thumbnailUrl,
      duration: event.duration,
      videoQuality: event.videoQuality?.label,
      audioQuality: event.audioQuality?.label,
      videoUrl: event.videoQuality?.url,
      audioUrl: event.audioQuality?.url,
      totalBytes: _calculateTotalBytes(event.videoQuality, event.audioQuality, event.downloadType),
    );

    // Add to active downloads
    final activeDownloads = List<DownloadItem>.from(state.activeDownloads);
    activeDownloads.add(item);
    emit(state.copyWith(activeDownloads: activeDownloads));

    // Show download started notification BEFORE starting download
    _notificationService.showDownloadStarted(item);

    // Start download (don't await - let it run in background)
    _downloadService.startDownload(
      item: item,
      onProgress: (updatedItem) {
        add(DownloadEvent.updateDownloadProgress(downloadItem: updatedItem));
      },
      onComplete: (completedItem) {
        add(DownloadEvent.downloadCompleted(downloadItem: completedItem));
      },
      onError: (failedItem, error) {
        add(DownloadEvent.downloadFailed(downloadItem: failedItem, error: error));
      },
    );
  }

  int? _calculateTotalBytes(
    VideoQualityOption? videoQuality,
    AudioQualityOption? audioQuality,
    DownloadType downloadType,
  ) {
    switch (downloadType) {
      case DownloadType.videoOnly:
        return videoQuality?.fileSize;
      case DownloadType.audioOnly:
        return audioQuality?.fileSize;
      case DownloadType.videoWithAudio:
        final videoSize = videoQuality?.fileSize ?? 0;
        final audioSize = audioQuality?.fileSize ?? 0;
        return videoSize + audioSize;
    }
  }

  Future<void> _onPauseDownload(
    _PauseDownload event,
    Emitter<DownloadState> emit,
  ) async {
    // Immediately update UI to show paused state
    final updatedActiveDownloads = state.activeDownloads.map((d) {
      if (d.id == event.downloadId) {
        final paused = d.copy();
        paused.status = DownloadStatus.paused;
        return paused;
      }
      return d;
    }).toList();

    final updatedAllDownloads = state.allDownloads.map((d) {
      if (d.id == event.downloadId) {
        final paused = d.copy();
        paused.status = DownloadStatus.paused;
        return paused;
      }
      return d;
    }).toList();

    // Move from active to pending
    final pausedItem = updatedActiveDownloads.firstWhere(
      (d) => d.id == event.downloadId,
      orElse: () => state.activeDownloads.first,
    );
    final newActiveDownloads = updatedActiveDownloads
        .where((d) => d.id != event.downloadId)
        .toList();
    final newPendingDownloads = List<DownloadItem>.from(state.pendingDownloads)
      ..insert(0, pausedItem);

    emit(state.copyWith(
      activeDownloads: newActiveDownloads,
      pendingDownloads: newPendingDownloads,
      allDownloads: updatedAllDownloads,
    ));

    await _downloadService.pauseDownload(event.downloadId);

    // Show paused notification
    _notificationService.showDownloadPaused(pausedItem);
  }

  Future<void> _onResumeDownload(
    _ResumeDownload event,
    Emitter<DownloadState> emit,
  ) async {
    // Immediately update UI to show downloading state
    DownloadItem? resumingItem;

    // Check pending downloads first (paused items)
    final updatedPendingDownloads = state.pendingDownloads.where((d) {
      if (d.id == event.downloadId) {
        resumingItem = d.copy();
        resumingItem!.status = DownloadStatus.downloading;
        return false; // Remove from pending
      }
      return true;
    }).toList();

    // If not found in pending, check allDownloads (failed items)
    if (resumingItem == null) {
      final failedItem = state.allDownloads.firstWhere(
        (d) => d.id == event.downloadId && d.status == DownloadStatus.failed,
        orElse: () => DownloadItem.create(
          videoId: '',
          title: '',
          channelName: '',
          downloadType: DownloadType.videoOnly,
        ),
      );
      if (failedItem.videoId.isNotEmpty) {
        resumingItem = failedItem.copy();
        resumingItem!.status = DownloadStatus.downloading;
      }
    }

    if (resumingItem != null) {
      final updatedActiveDownloads = List<DownloadItem>.from(state.activeDownloads)
        ..insert(0, resumingItem!);

      final updatedAllDownloads = state.allDownloads.map((d) {
        if (d.id == event.downloadId) {
          return resumingItem!;
        }
        return d;
      }).toList();

      emit(state.copyWith(
        activeDownloads: updatedActiveDownloads,
        pendingDownloads: updatedPendingDownloads,
        allDownloads: updatedAllDownloads,
      ));
    }

    await _downloadService.resumeDownload(
      downloadId: event.downloadId,
      onProgress: (updatedItem) {
        add(DownloadEvent.updateDownloadProgress(downloadItem: updatedItem));
      },
      onComplete: (completedItem) {
        add(DownloadEvent.downloadCompleted(downloadItem: completedItem));
      },
      onError: (failedItem, error) {
        add(DownloadEvent.downloadFailed(downloadItem: failedItem, error: error));
      },
    );
  }

  Future<void> _onCancelDownload(
    _CancelDownload event,
    Emitter<DownloadState> emit,
  ) async {
    await _downloadService.cancelDownload(event.downloadId);

    // Cancel notification
    _notificationService.cancelNotification(event.downloadId);

    // Remove from active downloads
    final activeDownloads = state.activeDownloads
        .where((d) => d.id != event.downloadId)
        .toList();
    emit(state.copyWith(activeDownloads: activeDownloads));

    add(const DownloadEvent.getAllDownloads());
  }

  Future<void> _onDeleteDownload(
    _DeleteDownload event,
    Emitter<DownloadState> emit,
  ) async {
    await _downloadService.deleteDownload(event.downloadId);
    add(const DownloadEvent.getAllDownloads());
  }

  Future<void> _onGetAllDownloads(
    _GetAllDownloads event,
    Emitter<DownloadState> emit,
  ) async {
    emit(state.copyWith(fetchDownloadsStatus: ApiStatus.loading));

    final result = await _downloadService.getAllDownloads(
      profileName: event.profileName,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        fetchDownloadsStatus: ApiStatus.error,
        errorMessage: failure.toString(),
      )),
      (downloads) {
        final completed = downloads
            .where((d) => d.status == DownloadStatus.completed)
            .toList();
        final active = downloads
            .where((d) => d.isActive)
            .toList();
        final pending = downloads
            .where((d) => d.status == DownloadStatus.pending || d.status == DownloadStatus.paused)
            .toList();

        emit(state.copyWith(
          fetchDownloadsStatus: ApiStatus.loaded,
          allDownloads: downloads,
          completedDownloads: completed,
          activeDownloads: active,
          pendingDownloads: pending,
        ));
      },
    );
  }

  // Track last phase to detect phase changes
  final Map<int, String?> _lastPhase = {};

  void _onUpdateDownloadProgress(
    _UpdateDownloadProgress event,
    Emitter<DownloadState> emit,
  ) {
    // Create a copy of the updated item to ensure state change is detected
    final updatedItem = event.downloadItem.copy();

    // Update item in activeDownloads
    final activeDownloads = state.activeDownloads.map((d) {
      if (d.id == updatedItem.id) {
        return updatedItem;
      }
      return d;
    }).toList();

    // Also update in allDownloads to reflect progress in All tab
    final allDownloads = state.allDownloads.map((d) {
      if (d.id == updatedItem.id) {
        return updatedItem;
      }
      return d;
    }).toList();

    emit(state.copyWith(
      activeDownloads: activeDownloads,
      allDownloads: allDownloads,
    ));

    // Update notification with throttling to avoid too many updates
    // But bypass throttling for phase changes (e.g., switching to merging)
    if (updatedItem.id != null) {
      final now = DateTime.now();
      final lastUpdate = _lastNotificationUpdate[updatedItem.id!];
      final previousPhase = _lastPhase[updatedItem.id!];
      final currentPhase = updatedItem.currentPhase;

      // Force update if phase changed (e.g., video -> audio -> merging)
      final phaseChanged = previousPhase != currentPhase;
      if (phaseChanged) {
        _lastPhase[updatedItem.id!] = currentPhase;
      }

      if (phaseChanged ||
          lastUpdate == null ||
          now.difference(lastUpdate) >= _notificationThrottleDuration) {
        _lastNotificationUpdate[updatedItem.id!] = now;
        _notificationService.showDownloadProgress(updatedItem);
      }
    }
  }

  void _onDownloadCompleted(
    _DownloadCompleted event,
    Emitter<DownloadState> emit,
  ) {
    // Create a copy to ensure state change is detected
    final completedItem = event.downloadItem.copy();

    // Remove from active and pending
    final activeDownloads = state.activeDownloads
        .where((d) => d.id != completedItem.id)
        .toList();
    final pendingDownloads = state.pendingDownloads
        .where((d) => d.id != completedItem.id)
        .toList();
    final completedDownloads = List<DownloadItem>.from(state.completedDownloads)
      ..insert(0, completedItem);

    // Update in allDownloads - either update existing or add new
    var allDownloads = state.allDownloads.map((d) {
      if (d.id == completedItem.id) {
        return completedItem;
      }
      return d;
    }).toList();

    // If not found in allDownloads, add it
    if (!allDownloads.any((d) => d.id == completedItem.id)) {
      allDownloads = [completedItem, ...allDownloads];
    }

    emit(state.copyWith(
      activeDownloads: activeDownloads,
      pendingDownloads: pendingDownloads,
      completedDownloads: completedDownloads,
      allDownloads: allDownloads,
    ));

    // Show completion notification and clean up tracking maps
    if (completedItem.id != null) {
      _lastNotificationUpdate.remove(completedItem.id!);
      _lastPhase.remove(completedItem.id!);
    }
    _notificationService.showDownloadCompleted(completedItem);
  }

  void _onDownloadFailed(
    _DownloadFailed event,
    Emitter<DownloadState> emit,
  ) {
    // Remove from active downloads
    final activeDownloads = state.activeDownloads
        .where((d) => d.id != event.downloadItem.id)
        .toList();

    emit(state.copyWith(
      activeDownloads: activeDownloads,
      errorMessage: event.error,
      failedDownloadTitle: event.downloadItem.title,
    ));

    // Show failure notification and clean up tracking maps
    if (event.downloadItem.id != null) {
      _lastNotificationUpdate.remove(event.downloadItem.id!);
      _lastPhase.remove(event.downloadItem.id!);
    }
    _notificationService.showDownloadFailed(event.downloadItem, event.error);
  }

  void _onClearDownloadOptions(
    _ClearDownloadOptions event,
    Emitter<DownloadState> emit,
  ) {
    emit(state.copyWith(
      downloadOptions: null,
      fetchOptionsStatus: ApiStatus.initial,
    ));
  }

  Future<void> _onSaveToDevice(
    _SaveToDevice event,
    Emitter<DownloadState> emit,
  ) async {
    emit(state.copyWith(
      saveToDeviceStatus: ApiStatus.loading,
      savedToDeviceTitle: null,
    ));

    final result = await _downloadService.saveToDevice(event.downloadItem);

    result.fold(
      (failure) => emit(state.copyWith(
        saveToDeviceStatus: ApiStatus.error,
        errorMessage: failure.toString(),
      )),
      (_) => emit(state.copyWith(
        saveToDeviceStatus: ApiStatus.loaded,
        savedToDeviceTitle: event.downloadItem.title,
      )),
    );
  }
}

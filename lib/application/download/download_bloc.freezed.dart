// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DownloadEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DownloadEventCopyWith<$Res> {
  factory $DownloadEventCopyWith(
          DownloadEvent value, $Res Function(DownloadEvent) then) =
      _$DownloadEventCopyWithImpl<$Res, DownloadEvent>;
}

/// @nodoc
class _$DownloadEventCopyWithImpl<$Res, $Val extends DownloadEvent>
    implements $DownloadEventCopyWith<$Res> {
  _$DownloadEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$GetDownloadOptionsImplCopyWith<$Res> {
  factory _$$GetDownloadOptionsImplCopyWith(_$GetDownloadOptionsImpl value,
          $Res Function(_$GetDownloadOptionsImpl) then) =
      __$$GetDownloadOptionsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String videoId, String serviceType});
}

/// @nodoc
class __$$GetDownloadOptionsImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$GetDownloadOptionsImpl>
    implements _$$GetDownloadOptionsImplCopyWith<$Res> {
  __$$GetDownloadOptionsImplCopyWithImpl(_$GetDownloadOptionsImpl _value,
      $Res Function(_$GetDownloadOptionsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? serviceType = null,
  }) {
    return _then(_$GetDownloadOptionsImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      serviceType: null == serviceType
          ? _value.serviceType
          : serviceType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$GetDownloadOptionsImpl implements _GetDownloadOptions {
  const _$GetDownloadOptionsImpl(
      {required this.videoId, required this.serviceType});

  @override
  final String videoId;
  @override
  final String serviceType;

  @override
  String toString() {
    return 'DownloadEvent.getDownloadOptions(videoId: $videoId, serviceType: $serviceType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GetDownloadOptionsImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.serviceType, serviceType) ||
                other.serviceType == serviceType));
  }

  @override
  int get hashCode => Object.hash(runtimeType, videoId, serviceType);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GetDownloadOptionsImplCopyWith<_$GetDownloadOptionsImpl> get copyWith =>
      __$$GetDownloadOptionsImplCopyWithImpl<_$GetDownloadOptionsImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return getDownloadOptions(videoId, serviceType);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return getDownloadOptions?.call(videoId, serviceType);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (getDownloadOptions != null) {
      return getDownloadOptions(videoId, serviceType);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return getDownloadOptions(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return getDownloadOptions?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (getDownloadOptions != null) {
      return getDownloadOptions(this);
    }
    return orElse();
  }
}

abstract class _GetDownloadOptions implements DownloadEvent {
  const factory _GetDownloadOptions(
      {required final String videoId,
      required final String serviceType}) = _$GetDownloadOptionsImpl;

  String get videoId;
  String get serviceType;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GetDownloadOptionsImplCopyWith<_$GetDownloadOptionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SetDownloadOptionsFromStreamsImplCopyWith<$Res> {
  factory _$$SetDownloadOptionsFromStreamsImplCopyWith(
          _$SetDownloadOptionsFromStreamsImpl value,
          $Res Function(_$SetDownloadOptionsFromStreamsImpl) then) =
      __$$SetDownloadOptionsFromStreamsImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String videoId,
      String title,
      String channelName,
      String? thumbnailUrl,
      int? duration,
      List<NewPipeVideoStream> videoStreams,
      List<NewPipeVideoStream> videoOnlyStreams,
      List<NewPipeAudioStream> audioStreams,
      String preferredCodec});
}

/// @nodoc
class __$$SetDownloadOptionsFromStreamsImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res,
        _$SetDownloadOptionsFromStreamsImpl>
    implements _$$SetDownloadOptionsFromStreamsImplCopyWith<$Res> {
  __$$SetDownloadOptionsFromStreamsImplCopyWithImpl(
      _$SetDownloadOptionsFromStreamsImpl _value,
      $Res Function(_$SetDownloadOptionsFromStreamsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? channelName = null,
    Object? thumbnailUrl = freezed,
    Object? duration = freezed,
    Object? videoStreams = null,
    Object? videoOnlyStreams = null,
    Object? audioStreams = null,
    Object? preferredCodec = null,
  }) {
    return _then(_$SetDownloadOptionsFromStreamsImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      channelName: null == channelName
          ? _value.channelName
          : channelName // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      videoStreams: null == videoStreams
          ? _value._videoStreams
          : videoStreams // ignore: cast_nullable_to_non_nullable
              as List<NewPipeVideoStream>,
      videoOnlyStreams: null == videoOnlyStreams
          ? _value._videoOnlyStreams
          : videoOnlyStreams // ignore: cast_nullable_to_non_nullable
              as List<NewPipeVideoStream>,
      audioStreams: null == audioStreams
          ? _value._audioStreams
          : audioStreams // ignore: cast_nullable_to_non_nullable
              as List<NewPipeAudioStream>,
      preferredCodec: null == preferredCodec
          ? _value.preferredCodec
          : preferredCodec // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$SetDownloadOptionsFromStreamsImpl
    implements _SetDownloadOptionsFromStreams {
  const _$SetDownloadOptionsFromStreamsImpl(
      {required this.videoId,
      required this.title,
      required this.channelName,
      this.thumbnailUrl,
      this.duration,
      required final List<NewPipeVideoStream> videoStreams,
      required final List<NewPipeVideoStream> videoOnlyStreams,
      required final List<NewPipeAudioStream> audioStreams,
      this.preferredCodec = defaultVideoCodecH264})
      : _videoStreams = videoStreams,
        _videoOnlyStreams = videoOnlyStreams,
        _audioStreams = audioStreams;

  @override
  final String videoId;
  @override
  final String title;
  @override
  final String channelName;
  @override
  final String? thumbnailUrl;
  @override
  final int? duration;
  final List<NewPipeVideoStream> _videoStreams;
  @override
  List<NewPipeVideoStream> get videoStreams {
    if (_videoStreams is EqualUnmodifiableListView) return _videoStreams;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videoStreams);
  }

  final List<NewPipeVideoStream> _videoOnlyStreams;
  @override
  List<NewPipeVideoStream> get videoOnlyStreams {
    if (_videoOnlyStreams is EqualUnmodifiableListView)
      return _videoOnlyStreams;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videoOnlyStreams);
  }

  final List<NewPipeAudioStream> _audioStreams;
  @override
  List<NewPipeAudioStream> get audioStreams {
    if (_audioStreams is EqualUnmodifiableListView) return _audioStreams;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_audioStreams);
  }

  @override
  final String preferredCodec;

  @override
  String toString() {
    return 'DownloadEvent.setDownloadOptionsFromStreams(videoId: $videoId, title: $title, channelName: $channelName, thumbnailUrl: $thumbnailUrl, duration: $duration, videoStreams: $videoStreams, videoOnlyStreams: $videoOnlyStreams, audioStreams: $audioStreams, preferredCodec: $preferredCodec)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetDownloadOptionsFromStreamsImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.channelName, channelName) ||
                other.channelName == channelName) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            const DeepCollectionEquality()
                .equals(other._videoStreams, _videoStreams) &&
            const DeepCollectionEquality()
                .equals(other._videoOnlyStreams, _videoOnlyStreams) &&
            const DeepCollectionEquality()
                .equals(other._audioStreams, _audioStreams) &&
            (identical(other.preferredCodec, preferredCodec) ||
                other.preferredCodec == preferredCodec));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      videoId,
      title,
      channelName,
      thumbnailUrl,
      duration,
      const DeepCollectionEquality().hash(_videoStreams),
      const DeepCollectionEquality().hash(_videoOnlyStreams),
      const DeepCollectionEquality().hash(_audioStreams),
      preferredCodec);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SetDownloadOptionsFromStreamsImplCopyWith<
          _$SetDownloadOptionsFromStreamsImpl>
      get copyWith => __$$SetDownloadOptionsFromStreamsImplCopyWithImpl<
          _$SetDownloadOptionsFromStreamsImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return setDownloadOptionsFromStreams(videoId, title, channelName,
        thumbnailUrl, duration, videoStreams, videoOnlyStreams, audioStreams,
        preferredCodec);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return setDownloadOptionsFromStreams?.call(videoId, title, channelName,
        thumbnailUrl, duration, videoStreams, videoOnlyStreams, audioStreams,
        preferredCodec);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (setDownloadOptionsFromStreams != null) {
      return setDownloadOptionsFromStreams(videoId, title, channelName,
          thumbnailUrl, duration, videoStreams, videoOnlyStreams, audioStreams,
          preferredCodec);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return setDownloadOptionsFromStreams(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return setDownloadOptionsFromStreams?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (setDownloadOptionsFromStreams != null) {
      return setDownloadOptionsFromStreams(this);
    }
    return orElse();
  }
}

abstract class _SetDownloadOptionsFromStreams implements DownloadEvent {
  const factory _SetDownloadOptionsFromStreams(
          {required final String videoId,
          required final String title,
          required final String channelName,
          final String? thumbnailUrl,
          final int? duration,
          required final List<NewPipeVideoStream> videoStreams,
          required final List<NewPipeVideoStream> videoOnlyStreams,
          required final List<NewPipeAudioStream> audioStreams,
          final String preferredCodec}) =
      _$SetDownloadOptionsFromStreamsImpl;

  String get videoId;
  String get title;
  String get channelName;
  String? get thumbnailUrl;
  int? get duration;
  List<NewPipeVideoStream> get videoStreams;
  List<NewPipeVideoStream> get videoOnlyStreams;
  List<NewPipeAudioStream> get audioStreams;
  String get preferredCodec;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetDownloadOptionsFromStreamsImplCopyWith<
          _$SetDownloadOptionsFromStreamsImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StartDownloadImplCopyWith<$Res> {
  factory _$$StartDownloadImplCopyWith(
          _$StartDownloadImpl value, $Res Function(_$StartDownloadImpl) then) =
      __$$StartDownloadImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String videoId,
      String title,
      String channelName,
      DownloadType downloadType,
      String profileName,
      String? thumbnailUrl,
      int? duration,
      VideoQualityOption? videoQuality,
      AudioQualityOption? audioQuality});
}

/// @nodoc
class __$$StartDownloadImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$StartDownloadImpl>
    implements _$$StartDownloadImplCopyWith<$Res> {
  __$$StartDownloadImplCopyWithImpl(
      _$StartDownloadImpl _value, $Res Function(_$StartDownloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? channelName = null,
    Object? downloadType = null,
    Object? profileName = null,
    Object? thumbnailUrl = freezed,
    Object? duration = freezed,
    Object? videoQuality = freezed,
    Object? audioQuality = freezed,
  }) {
    return _then(_$StartDownloadImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      channelName: null == channelName
          ? _value.channelName
          : channelName // ignore: cast_nullable_to_non_nullable
              as String,
      downloadType: null == downloadType
          ? _value.downloadType
          : downloadType // ignore: cast_nullable_to_non_nullable
              as DownloadType,
      profileName: null == profileName
          ? _value.profileName
          : profileName // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      videoQuality: freezed == videoQuality
          ? _value.videoQuality
          : videoQuality // ignore: cast_nullable_to_non_nullable
              as VideoQualityOption?,
      audioQuality: freezed == audioQuality
          ? _value.audioQuality
          : audioQuality // ignore: cast_nullable_to_non_nullable
              as AudioQualityOption?,
    ));
  }
}

/// @nodoc

class _$StartDownloadImpl implements _StartDownload {
  const _$StartDownloadImpl(
      {required this.videoId,
      required this.title,
      required this.channelName,
      required this.downloadType,
      this.profileName = 'default',
      this.thumbnailUrl,
      this.duration,
      this.videoQuality,
      this.audioQuality});

  @override
  final String videoId;
  @override
  final String title;
  @override
  final String channelName;
  @override
  final DownloadType downloadType;
  @override
  @JsonKey()
  final String profileName;
  @override
  final String? thumbnailUrl;
  @override
  final int? duration;
  @override
  final VideoQualityOption? videoQuality;
  @override
  final AudioQualityOption? audioQuality;

  @override
  String toString() {
    return 'DownloadEvent.startDownload(videoId: $videoId, title: $title, channelName: $channelName, downloadType: $downloadType, profileName: $profileName, thumbnailUrl: $thumbnailUrl, duration: $duration, videoQuality: $videoQuality, audioQuality: $audioQuality)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StartDownloadImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.channelName, channelName) ||
                other.channelName == channelName) &&
            (identical(other.downloadType, downloadType) ||
                other.downloadType == downloadType) &&
            (identical(other.profileName, profileName) ||
                other.profileName == profileName) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.videoQuality, videoQuality) ||
                other.videoQuality == videoQuality) &&
            (identical(other.audioQuality, audioQuality) ||
                other.audioQuality == audioQuality));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      videoId,
      title,
      channelName,
      downloadType,
      profileName,
      thumbnailUrl,
      duration,
      videoQuality,
      audioQuality);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StartDownloadImplCopyWith<_$StartDownloadImpl> get copyWith =>
      __$$StartDownloadImplCopyWithImpl<_$StartDownloadImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return startDownload(videoId, title, channelName, downloadType, profileName,
        thumbnailUrl, duration, videoQuality, audioQuality);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return startDownload?.call(videoId, title, channelName, downloadType,
        profileName, thumbnailUrl, duration, videoQuality, audioQuality);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (startDownload != null) {
      return startDownload(videoId, title, channelName, downloadType,
          profileName, thumbnailUrl, duration, videoQuality, audioQuality);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return startDownload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return startDownload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (startDownload != null) {
      return startDownload(this);
    }
    return orElse();
  }
}

abstract class _StartDownload implements DownloadEvent {
  const factory _StartDownload(
      {required final String videoId,
      required final String title,
      required final String channelName,
      required final DownloadType downloadType,
      final String profileName,
      final String? thumbnailUrl,
      final int? duration,
      final VideoQualityOption? videoQuality,
      final AudioQualityOption? audioQuality}) = _$StartDownloadImpl;

  String get videoId;
  String get title;
  String get channelName;
  DownloadType get downloadType;
  String get profileName;
  String? get thumbnailUrl;
  int? get duration;
  VideoQualityOption? get videoQuality;
  AudioQualityOption? get audioQuality;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StartDownloadImplCopyWith<_$StartDownloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PauseDownloadImplCopyWith<$Res> {
  factory _$$PauseDownloadImplCopyWith(
          _$PauseDownloadImpl value, $Res Function(_$PauseDownloadImpl) then) =
      __$$PauseDownloadImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int downloadId});
}

/// @nodoc
class __$$PauseDownloadImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$PauseDownloadImpl>
    implements _$$PauseDownloadImplCopyWith<$Res> {
  __$$PauseDownloadImplCopyWithImpl(
      _$PauseDownloadImpl _value, $Res Function(_$PauseDownloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadId = null,
  }) {
    return _then(_$PauseDownloadImpl(
      downloadId: null == downloadId
          ? _value.downloadId
          : downloadId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$PauseDownloadImpl implements _PauseDownload {
  const _$PauseDownloadImpl({required this.downloadId});

  @override
  final int downloadId;

  @override
  String toString() {
    return 'DownloadEvent.pauseDownload(downloadId: $downloadId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PauseDownloadImpl &&
            (identical(other.downloadId, downloadId) ||
                other.downloadId == downloadId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadId);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PauseDownloadImplCopyWith<_$PauseDownloadImpl> get copyWith =>
      __$$PauseDownloadImplCopyWithImpl<_$PauseDownloadImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return pauseDownload(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return pauseDownload?.call(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (pauseDownload != null) {
      return pauseDownload(downloadId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return pauseDownload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return pauseDownload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (pauseDownload != null) {
      return pauseDownload(this);
    }
    return orElse();
  }
}

abstract class _PauseDownload implements DownloadEvent {
  const factory _PauseDownload({required final int downloadId}) =
      _$PauseDownloadImpl;

  int get downloadId;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PauseDownloadImplCopyWith<_$PauseDownloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ResumeDownloadImplCopyWith<$Res> {
  factory _$$ResumeDownloadImplCopyWith(_$ResumeDownloadImpl value,
          $Res Function(_$ResumeDownloadImpl) then) =
      __$$ResumeDownloadImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int downloadId});
}

/// @nodoc
class __$$ResumeDownloadImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$ResumeDownloadImpl>
    implements _$$ResumeDownloadImplCopyWith<$Res> {
  __$$ResumeDownloadImplCopyWithImpl(
      _$ResumeDownloadImpl _value, $Res Function(_$ResumeDownloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadId = null,
  }) {
    return _then(_$ResumeDownloadImpl(
      downloadId: null == downloadId
          ? _value.downloadId
          : downloadId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ResumeDownloadImpl implements _ResumeDownload {
  const _$ResumeDownloadImpl({required this.downloadId});

  @override
  final int downloadId;

  @override
  String toString() {
    return 'DownloadEvent.resumeDownload(downloadId: $downloadId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ResumeDownloadImpl &&
            (identical(other.downloadId, downloadId) ||
                other.downloadId == downloadId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadId);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ResumeDownloadImplCopyWith<_$ResumeDownloadImpl> get copyWith =>
      __$$ResumeDownloadImplCopyWithImpl<_$ResumeDownloadImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return resumeDownload(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return resumeDownload?.call(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (resumeDownload != null) {
      return resumeDownload(downloadId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return resumeDownload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return resumeDownload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (resumeDownload != null) {
      return resumeDownload(this);
    }
    return orElse();
  }
}

abstract class _ResumeDownload implements DownloadEvent {
  const factory _ResumeDownload({required final int downloadId}) =
      _$ResumeDownloadImpl;

  int get downloadId;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ResumeDownloadImplCopyWith<_$ResumeDownloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CancelDownloadImplCopyWith<$Res> {
  factory _$$CancelDownloadImplCopyWith(_$CancelDownloadImpl value,
          $Res Function(_$CancelDownloadImpl) then) =
      __$$CancelDownloadImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int downloadId});
}

/// @nodoc
class __$$CancelDownloadImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$CancelDownloadImpl>
    implements _$$CancelDownloadImplCopyWith<$Res> {
  __$$CancelDownloadImplCopyWithImpl(
      _$CancelDownloadImpl _value, $Res Function(_$CancelDownloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadId = null,
  }) {
    return _then(_$CancelDownloadImpl(
      downloadId: null == downloadId
          ? _value.downloadId
          : downloadId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$CancelDownloadImpl implements _CancelDownload {
  const _$CancelDownloadImpl({required this.downloadId});

  @override
  final int downloadId;

  @override
  String toString() {
    return 'DownloadEvent.cancelDownload(downloadId: $downloadId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CancelDownloadImpl &&
            (identical(other.downloadId, downloadId) ||
                other.downloadId == downloadId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadId);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CancelDownloadImplCopyWith<_$CancelDownloadImpl> get copyWith =>
      __$$CancelDownloadImplCopyWithImpl<_$CancelDownloadImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return cancelDownload(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return cancelDownload?.call(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (cancelDownload != null) {
      return cancelDownload(downloadId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return cancelDownload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return cancelDownload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (cancelDownload != null) {
      return cancelDownload(this);
    }
    return orElse();
  }
}

abstract class _CancelDownload implements DownloadEvent {
  const factory _CancelDownload({required final int downloadId}) =
      _$CancelDownloadImpl;

  int get downloadId;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CancelDownloadImplCopyWith<_$CancelDownloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DeleteDownloadImplCopyWith<$Res> {
  factory _$$DeleteDownloadImplCopyWith(_$DeleteDownloadImpl value,
          $Res Function(_$DeleteDownloadImpl) then) =
      __$$DeleteDownloadImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int downloadId});
}

/// @nodoc
class __$$DeleteDownloadImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$DeleteDownloadImpl>
    implements _$$DeleteDownloadImplCopyWith<$Res> {
  __$$DeleteDownloadImplCopyWithImpl(
      _$DeleteDownloadImpl _value, $Res Function(_$DeleteDownloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadId = null,
  }) {
    return _then(_$DeleteDownloadImpl(
      downloadId: null == downloadId
          ? _value.downloadId
          : downloadId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$DeleteDownloadImpl implements _DeleteDownload {
  const _$DeleteDownloadImpl({required this.downloadId});

  @override
  final int downloadId;

  @override
  String toString() {
    return 'DownloadEvent.deleteDownload(downloadId: $downloadId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeleteDownloadImpl &&
            (identical(other.downloadId, downloadId) ||
                other.downloadId == downloadId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadId);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeleteDownloadImplCopyWith<_$DeleteDownloadImpl> get copyWith =>
      __$$DeleteDownloadImplCopyWithImpl<_$DeleteDownloadImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return deleteDownload(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return deleteDownload?.call(downloadId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (deleteDownload != null) {
      return deleteDownload(downloadId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return deleteDownload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return deleteDownload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (deleteDownload != null) {
      return deleteDownload(this);
    }
    return orElse();
  }
}

abstract class _DeleteDownload implements DownloadEvent {
  const factory _DeleteDownload({required final int downloadId}) =
      _$DeleteDownloadImpl;

  int get downloadId;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeleteDownloadImplCopyWith<_$DeleteDownloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GetAllDownloadsImplCopyWith<$Res> {
  factory _$$GetAllDownloadsImplCopyWith(_$GetAllDownloadsImpl value,
          $Res Function(_$GetAllDownloadsImpl) then) =
      __$$GetAllDownloadsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String profileName});
}

/// @nodoc
class __$$GetAllDownloadsImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$GetAllDownloadsImpl>
    implements _$$GetAllDownloadsImplCopyWith<$Res> {
  __$$GetAllDownloadsImplCopyWithImpl(
      _$GetAllDownloadsImpl _value, $Res Function(_$GetAllDownloadsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profileName = null,
  }) {
    return _then(_$GetAllDownloadsImpl(
      profileName: null == profileName
          ? _value.profileName
          : profileName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$GetAllDownloadsImpl implements _GetAllDownloads {
  const _$GetAllDownloadsImpl({this.profileName = 'default'});

  @override
  @JsonKey()
  final String profileName;

  @override
  String toString() {
    return 'DownloadEvent.getAllDownloads(profileName: $profileName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GetAllDownloadsImpl &&
            (identical(other.profileName, profileName) ||
                other.profileName == profileName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, profileName);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GetAllDownloadsImplCopyWith<_$GetAllDownloadsImpl> get copyWith =>
      __$$GetAllDownloadsImplCopyWithImpl<_$GetAllDownloadsImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return getAllDownloads(profileName);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return getAllDownloads?.call(profileName);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (getAllDownloads != null) {
      return getAllDownloads(profileName);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return getAllDownloads(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return getAllDownloads?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (getAllDownloads != null) {
      return getAllDownloads(this);
    }
    return orElse();
  }
}

abstract class _GetAllDownloads implements DownloadEvent {
  const factory _GetAllDownloads({final String profileName}) =
      _$GetAllDownloadsImpl;

  String get profileName;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GetAllDownloadsImplCopyWith<_$GetAllDownloadsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UpdateDownloadProgressImplCopyWith<$Res> {
  factory _$$UpdateDownloadProgressImplCopyWith(
          _$UpdateDownloadProgressImpl value,
          $Res Function(_$UpdateDownloadProgressImpl) then) =
      __$$UpdateDownloadProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DownloadItem downloadItem});
}

/// @nodoc
class __$$UpdateDownloadProgressImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$UpdateDownloadProgressImpl>
    implements _$$UpdateDownloadProgressImplCopyWith<$Res> {
  __$$UpdateDownloadProgressImplCopyWithImpl(
      _$UpdateDownloadProgressImpl _value,
      $Res Function(_$UpdateDownloadProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadItem = null,
  }) {
    return _then(_$UpdateDownloadProgressImpl(
      downloadItem: null == downloadItem
          ? _value.downloadItem
          : downloadItem // ignore: cast_nullable_to_non_nullable
              as DownloadItem,
    ));
  }
}

/// @nodoc

class _$UpdateDownloadProgressImpl implements _UpdateDownloadProgress {
  const _$UpdateDownloadProgressImpl({required this.downloadItem});

  @override
  final DownloadItem downloadItem;

  @override
  String toString() {
    return 'DownloadEvent.updateDownloadProgress(downloadItem: $downloadItem)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateDownloadProgressImpl &&
            (identical(other.downloadItem, downloadItem) ||
                other.downloadItem == downloadItem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadItem);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateDownloadProgressImplCopyWith<_$UpdateDownloadProgressImpl>
      get copyWith => __$$UpdateDownloadProgressImplCopyWithImpl<
          _$UpdateDownloadProgressImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return updateDownloadProgress(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return updateDownloadProgress?.call(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (updateDownloadProgress != null) {
      return updateDownloadProgress(downloadItem);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return updateDownloadProgress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return updateDownloadProgress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (updateDownloadProgress != null) {
      return updateDownloadProgress(this);
    }
    return orElse();
  }
}

abstract class _UpdateDownloadProgress implements DownloadEvent {
  const factory _UpdateDownloadProgress(
          {required final DownloadItem downloadItem}) =
      _$UpdateDownloadProgressImpl;

  DownloadItem get downloadItem;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpdateDownloadProgressImplCopyWith<_$UpdateDownloadProgressImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DownloadCompletedImplCopyWith<$Res> {
  factory _$$DownloadCompletedImplCopyWith(_$DownloadCompletedImpl value,
          $Res Function(_$DownloadCompletedImpl) then) =
      __$$DownloadCompletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DownloadItem downloadItem});
}

/// @nodoc
class __$$DownloadCompletedImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$DownloadCompletedImpl>
    implements _$$DownloadCompletedImplCopyWith<$Res> {
  __$$DownloadCompletedImplCopyWithImpl(_$DownloadCompletedImpl _value,
      $Res Function(_$DownloadCompletedImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadItem = null,
  }) {
    return _then(_$DownloadCompletedImpl(
      downloadItem: null == downloadItem
          ? _value.downloadItem
          : downloadItem // ignore: cast_nullable_to_non_nullable
              as DownloadItem,
    ));
  }
}

/// @nodoc

class _$DownloadCompletedImpl implements _DownloadCompleted {
  const _$DownloadCompletedImpl({required this.downloadItem});

  @override
  final DownloadItem downloadItem;

  @override
  String toString() {
    return 'DownloadEvent.downloadCompleted(downloadItem: $downloadItem)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadCompletedImpl &&
            (identical(other.downloadItem, downloadItem) ||
                other.downloadItem == downloadItem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadItem);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadCompletedImplCopyWith<_$DownloadCompletedImpl> get copyWith =>
      __$$DownloadCompletedImplCopyWithImpl<_$DownloadCompletedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return downloadCompleted(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return downloadCompleted?.call(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (downloadCompleted != null) {
      return downloadCompleted(downloadItem);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return downloadCompleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return downloadCompleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (downloadCompleted != null) {
      return downloadCompleted(this);
    }
    return orElse();
  }
}

abstract class _DownloadCompleted implements DownloadEvent {
  const factory _DownloadCompleted({required final DownloadItem downloadItem}) =
      _$DownloadCompletedImpl;

  DownloadItem get downloadItem;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DownloadCompletedImplCopyWith<_$DownloadCompletedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DownloadFailedImplCopyWith<$Res> {
  factory _$$DownloadFailedImplCopyWith(_$DownloadFailedImpl value,
          $Res Function(_$DownloadFailedImpl) then) =
      __$$DownloadFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DownloadItem downloadItem, String error});
}

/// @nodoc
class __$$DownloadFailedImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$DownloadFailedImpl>
    implements _$$DownloadFailedImplCopyWith<$Res> {
  __$$DownloadFailedImplCopyWithImpl(
      _$DownloadFailedImpl _value, $Res Function(_$DownloadFailedImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadItem = null,
    Object? error = null,
  }) {
    return _then(_$DownloadFailedImpl(
      downloadItem: null == downloadItem
          ? _value.downloadItem
          : downloadItem // ignore: cast_nullable_to_non_nullable
              as DownloadItem,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$DownloadFailedImpl implements _DownloadFailed {
  const _$DownloadFailedImpl({required this.downloadItem, required this.error});

  @override
  final DownloadItem downloadItem;
  @override
  final String error;

  @override
  String toString() {
    return 'DownloadEvent.downloadFailed(downloadItem: $downloadItem, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadFailedImpl &&
            (identical(other.downloadItem, downloadItem) ||
                other.downloadItem == downloadItem) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadItem, error);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadFailedImplCopyWith<_$DownloadFailedImpl> get copyWith =>
      __$$DownloadFailedImplCopyWithImpl<_$DownloadFailedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return downloadFailed(downloadItem, error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return downloadFailed?.call(downloadItem, error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (downloadFailed != null) {
      return downloadFailed(downloadItem, error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return downloadFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return downloadFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (downloadFailed != null) {
      return downloadFailed(this);
    }
    return orElse();
  }
}

abstract class _DownloadFailed implements DownloadEvent {
  const factory _DownloadFailed(
      {required final DownloadItem downloadItem,
      required final String error}) = _$DownloadFailedImpl;

  DownloadItem get downloadItem;
  String get error;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DownloadFailedImplCopyWith<_$DownloadFailedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ClearDownloadOptionsImplCopyWith<$Res> {
  factory _$$ClearDownloadOptionsImplCopyWith(_$ClearDownloadOptionsImpl value,
          $Res Function(_$ClearDownloadOptionsImpl) then) =
      __$$ClearDownloadOptionsImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ClearDownloadOptionsImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$ClearDownloadOptionsImpl>
    implements _$$ClearDownloadOptionsImplCopyWith<$Res> {
  __$$ClearDownloadOptionsImplCopyWithImpl(_$ClearDownloadOptionsImpl _value,
      $Res Function(_$ClearDownloadOptionsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ClearDownloadOptionsImpl implements _ClearDownloadOptions {
  const _$ClearDownloadOptionsImpl();

  @override
  String toString() {
    return 'DownloadEvent.clearDownloadOptions()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClearDownloadOptionsImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return clearDownloadOptions();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return clearDownloadOptions?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (clearDownloadOptions != null) {
      return clearDownloadOptions();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return clearDownloadOptions(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return clearDownloadOptions?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (clearDownloadOptions != null) {
      return clearDownloadOptions(this);
    }
    return orElse();
  }
}

abstract class _ClearDownloadOptions implements DownloadEvent {
  const factory _ClearDownloadOptions() = _$ClearDownloadOptionsImpl;
}

/// @nodoc
abstract class _$$SaveToDeviceImplCopyWith<$Res> {
  factory _$$SaveToDeviceImplCopyWith(
          _$SaveToDeviceImpl value, $Res Function(_$SaveToDeviceImpl) then) =
      __$$SaveToDeviceImplCopyWithImpl<$Res>;
  @useResult
  $Res call({DownloadItem downloadItem});
}

/// @nodoc
class __$$SaveToDeviceImplCopyWithImpl<$Res>
    extends _$DownloadEventCopyWithImpl<$Res, _$SaveToDeviceImpl>
    implements _$$SaveToDeviceImplCopyWith<$Res> {
  __$$SaveToDeviceImplCopyWithImpl(
      _$SaveToDeviceImpl _value, $Res Function(_$SaveToDeviceImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadItem = null,
  }) {
    return _then(_$SaveToDeviceImpl(
      downloadItem: null == downloadItem
          ? _value.downloadItem
          : downloadItem // ignore: cast_nullable_to_non_nullable
              as DownloadItem,
    ));
  }
}

/// @nodoc

class _$SaveToDeviceImpl implements _SaveToDevice {
  const _$SaveToDeviceImpl({required this.downloadItem});

  @override
  final DownloadItem downloadItem;

  @override
  String toString() {
    return 'DownloadEvent.saveToDevice(downloadItem: $downloadItem)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SaveToDeviceImpl &&
            (identical(other.downloadItem, downloadItem) ||
                other.downloadItem == downloadItem));
  }

  @override
  int get hashCode => Object.hash(runtimeType, downloadItem);

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SaveToDeviceImplCopyWith<_$SaveToDeviceImpl> get copyWith =>
      __$$SaveToDeviceImplCopyWithImpl<_$SaveToDeviceImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String videoId, String serviceType)
        getDownloadOptions,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)
        setDownloadOptionsFromStreams,
    required TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)
        startDownload,
    required TResult Function(int downloadId) pauseDownload,
    required TResult Function(int downloadId) resumeDownload,
    required TResult Function(int downloadId) cancelDownload,
    required TResult Function(int downloadId) deleteDownload,
    required TResult Function(String profileName) getAllDownloads,
    required TResult Function(DownloadItem downloadItem) updateDownloadProgress,
    required TResult Function(DownloadItem downloadItem) downloadCompleted,
    required TResult Function(DownloadItem downloadItem, String error)
        downloadFailed,
    required TResult Function() clearDownloadOptions,
    required TResult Function(DownloadItem downloadItem) saveToDevice,
  }) {
    return saveToDevice(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String videoId, String serviceType)? getDownloadOptions,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult? Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult? Function(int downloadId)? pauseDownload,
    TResult? Function(int downloadId)? resumeDownload,
    TResult? Function(int downloadId)? cancelDownload,
    TResult? Function(int downloadId)? deleteDownload,
    TResult? Function(String profileName)? getAllDownloads,
    TResult? Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult? Function(DownloadItem downloadItem)? downloadCompleted,
    TResult? Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult? Function()? clearDownloadOptions,
    TResult? Function(DownloadItem downloadItem)? saveToDevice,
  }) {
    return saveToDevice?.call(downloadItem);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String videoId, String serviceType)? getDownloadOptions,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            String? thumbnailUrl,
            int? duration,
            List<NewPipeVideoStream> videoStreams,
            List<NewPipeVideoStream> videoOnlyStreams,
            List<NewPipeAudioStream> audioStreams,
            String preferredCodec)?
        setDownloadOptionsFromStreams,
    TResult Function(
            String videoId,
            String title,
            String channelName,
            DownloadType downloadType,
            String profileName,
            String? thumbnailUrl,
            int? duration,
            VideoQualityOption? videoQuality,
            AudioQualityOption? audioQuality)?
        startDownload,
    TResult Function(int downloadId)? pauseDownload,
    TResult Function(int downloadId)? resumeDownload,
    TResult Function(int downloadId)? cancelDownload,
    TResult Function(int downloadId)? deleteDownload,
    TResult Function(String profileName)? getAllDownloads,
    TResult Function(DownloadItem downloadItem)? updateDownloadProgress,
    TResult Function(DownloadItem downloadItem)? downloadCompleted,
    TResult Function(DownloadItem downloadItem, String error)? downloadFailed,
    TResult Function()? clearDownloadOptions,
    TResult Function(DownloadItem downloadItem)? saveToDevice,
    required TResult orElse(),
  }) {
    if (saveToDevice != null) {
      return saveToDevice(downloadItem);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_GetDownloadOptions value) getDownloadOptions,
    required TResult Function(_SetDownloadOptionsFromStreams value)
        setDownloadOptionsFromStreams,
    required TResult Function(_StartDownload value) startDownload,
    required TResult Function(_PauseDownload value) pauseDownload,
    required TResult Function(_ResumeDownload value) resumeDownload,
    required TResult Function(_CancelDownload value) cancelDownload,
    required TResult Function(_DeleteDownload value) deleteDownload,
    required TResult Function(_GetAllDownloads value) getAllDownloads,
    required TResult Function(_UpdateDownloadProgress value)
        updateDownloadProgress,
    required TResult Function(_DownloadCompleted value) downloadCompleted,
    required TResult Function(_DownloadFailed value) downloadFailed,
    required TResult Function(_ClearDownloadOptions value) clearDownloadOptions,
    required TResult Function(_SaveToDevice value) saveToDevice,
  }) {
    return saveToDevice(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult? Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult? Function(_StartDownload value)? startDownload,
    TResult? Function(_PauseDownload value)? pauseDownload,
    TResult? Function(_ResumeDownload value)? resumeDownload,
    TResult? Function(_CancelDownload value)? cancelDownload,
    TResult? Function(_DeleteDownload value)? deleteDownload,
    TResult? Function(_GetAllDownloads value)? getAllDownloads,
    TResult? Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult? Function(_DownloadCompleted value)? downloadCompleted,
    TResult? Function(_DownloadFailed value)? downloadFailed,
    TResult? Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult? Function(_SaveToDevice value)? saveToDevice,
  }) {
    return saveToDevice?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_GetDownloadOptions value)? getDownloadOptions,
    TResult Function(_SetDownloadOptionsFromStreams value)?
        setDownloadOptionsFromStreams,
    TResult Function(_StartDownload value)? startDownload,
    TResult Function(_PauseDownload value)? pauseDownload,
    TResult Function(_ResumeDownload value)? resumeDownload,
    TResult Function(_CancelDownload value)? cancelDownload,
    TResult Function(_DeleteDownload value)? deleteDownload,
    TResult Function(_GetAllDownloads value)? getAllDownloads,
    TResult Function(_UpdateDownloadProgress value)? updateDownloadProgress,
    TResult Function(_DownloadCompleted value)? downloadCompleted,
    TResult Function(_DownloadFailed value)? downloadFailed,
    TResult Function(_ClearDownloadOptions value)? clearDownloadOptions,
    TResult Function(_SaveToDevice value)? saveToDevice,
    required TResult orElse(),
  }) {
    if (saveToDevice != null) {
      return saveToDevice(this);
    }
    return orElse();
  }
}

abstract class _SaveToDevice implements DownloadEvent {
  const factory _SaveToDevice({required final DownloadItem downloadItem}) =
      _$SaveToDeviceImpl;

  DownloadItem get downloadItem;

  /// Create a copy of DownloadEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SaveToDeviceImplCopyWith<_$SaveToDeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DownloadState {
  /// Status of fetching download options
  ApiStatus get fetchOptionsStatus => throw _privateConstructorUsedError;

  /// Status of fetching downloads list
  ApiStatus get fetchDownloadsStatus => throw _privateConstructorUsedError;

  /// Available download options for current video
  DownloadOptions? get downloadOptions => throw _privateConstructorUsedError;

  /// All downloads
  List<DownloadItem> get allDownloads => throw _privateConstructorUsedError;

  /// Completed downloads
  List<DownloadItem> get completedDownloads =>
      throw _privateConstructorUsedError;

  /// Active (currently downloading) downloads
  List<DownloadItem> get activeDownloads => throw _privateConstructorUsedError;

  /// Pending or paused downloads
  List<DownloadItem> get pendingDownloads => throw _privateConstructorUsedError;

  /// Error message if any
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Title of the failed download (for snackbar display)
  String? get failedDownloadTitle => throw _privateConstructorUsedError;

  /// Save to device operation status
  ApiStatus get saveToDeviceStatus => throw _privateConstructorUsedError;

  /// Title of the file that was saved to device (for success message)
  String? get savedToDeviceTitle => throw _privateConstructorUsedError;

  /// Create a copy of DownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DownloadStateCopyWith<DownloadState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DownloadStateCopyWith<$Res> {
  factory $DownloadStateCopyWith(
          DownloadState value, $Res Function(DownloadState) then) =
      _$DownloadStateCopyWithImpl<$Res, DownloadState>;
  @useResult
  $Res call(
      {ApiStatus fetchOptionsStatus,
      ApiStatus fetchDownloadsStatus,
      DownloadOptions? downloadOptions,
      List<DownloadItem> allDownloads,
      List<DownloadItem> completedDownloads,
      List<DownloadItem> activeDownloads,
      List<DownloadItem> pendingDownloads,
      String? errorMessage,
      String? failedDownloadTitle,
      ApiStatus saveToDeviceStatus,
      String? savedToDeviceTitle});
}

/// @nodoc
class _$DownloadStateCopyWithImpl<$Res, $Val extends DownloadState>
    implements $DownloadStateCopyWith<$Res> {
  _$DownloadStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fetchOptionsStatus = null,
    Object? fetchDownloadsStatus = null,
    Object? downloadOptions = freezed,
    Object? allDownloads = null,
    Object? completedDownloads = null,
    Object? activeDownloads = null,
    Object? pendingDownloads = null,
    Object? errorMessage = freezed,
    Object? failedDownloadTitle = freezed,
    Object? saveToDeviceStatus = null,
    Object? savedToDeviceTitle = freezed,
  }) {
    return _then(_value.copyWith(
      fetchOptionsStatus: null == fetchOptionsStatus
          ? _value.fetchOptionsStatus
          : fetchOptionsStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      fetchDownloadsStatus: null == fetchDownloadsStatus
          ? _value.fetchDownloadsStatus
          : fetchDownloadsStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      downloadOptions: freezed == downloadOptions
          ? _value.downloadOptions
          : downloadOptions // ignore: cast_nullable_to_non_nullable
              as DownloadOptions?,
      allDownloads: null == allDownloads
          ? _value.allDownloads
          : allDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      completedDownloads: null == completedDownloads
          ? _value.completedDownloads
          : completedDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      activeDownloads: null == activeDownloads
          ? _value.activeDownloads
          : activeDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      pendingDownloads: null == pendingDownloads
          ? _value.pendingDownloads
          : pendingDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      failedDownloadTitle: freezed == failedDownloadTitle
          ? _value.failedDownloadTitle
          : failedDownloadTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      saveToDeviceStatus: null == saveToDeviceStatus
          ? _value.saveToDeviceStatus
          : saveToDeviceStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      savedToDeviceTitle: freezed == savedToDeviceTitle
          ? _value.savedToDeviceTitle
          : savedToDeviceTitle // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DownloadStateImplCopyWith<$Res>
    implements $DownloadStateCopyWith<$Res> {
  factory _$$DownloadStateImplCopyWith(
          _$DownloadStateImpl value, $Res Function(_$DownloadStateImpl) then) =
      __$$DownloadStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ApiStatus fetchOptionsStatus,
      ApiStatus fetchDownloadsStatus,
      DownloadOptions? downloadOptions,
      List<DownloadItem> allDownloads,
      List<DownloadItem> completedDownloads,
      List<DownloadItem> activeDownloads,
      List<DownloadItem> pendingDownloads,
      String? errorMessage,
      String? failedDownloadTitle,
      ApiStatus saveToDeviceStatus,
      String? savedToDeviceTitle});
}

/// @nodoc
class __$$DownloadStateImplCopyWithImpl<$Res>
    extends _$DownloadStateCopyWithImpl<$Res, _$DownloadStateImpl>
    implements _$$DownloadStateImplCopyWith<$Res> {
  __$$DownloadStateImplCopyWithImpl(
      _$DownloadStateImpl _value, $Res Function(_$DownloadStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of DownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fetchOptionsStatus = null,
    Object? fetchDownloadsStatus = null,
    Object? downloadOptions = freezed,
    Object? allDownloads = null,
    Object? completedDownloads = null,
    Object? activeDownloads = null,
    Object? pendingDownloads = null,
    Object? errorMessage = freezed,
    Object? failedDownloadTitle = freezed,
    Object? saveToDeviceStatus = null,
    Object? savedToDeviceTitle = freezed,
  }) {
    return _then(_$DownloadStateImpl(
      fetchOptionsStatus: null == fetchOptionsStatus
          ? _value.fetchOptionsStatus
          : fetchOptionsStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      fetchDownloadsStatus: null == fetchDownloadsStatus
          ? _value.fetchDownloadsStatus
          : fetchDownloadsStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      downloadOptions: freezed == downloadOptions
          ? _value.downloadOptions
          : downloadOptions // ignore: cast_nullable_to_non_nullable
              as DownloadOptions?,
      allDownloads: null == allDownloads
          ? _value._allDownloads
          : allDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      completedDownloads: null == completedDownloads
          ? _value._completedDownloads
          : completedDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      activeDownloads: null == activeDownloads
          ? _value._activeDownloads
          : activeDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      pendingDownloads: null == pendingDownloads
          ? _value._pendingDownloads
          : pendingDownloads // ignore: cast_nullable_to_non_nullable
              as List<DownloadItem>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      failedDownloadTitle: freezed == failedDownloadTitle
          ? _value.failedDownloadTitle
          : failedDownloadTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      saveToDeviceStatus: null == saveToDeviceStatus
          ? _value.saveToDeviceStatus
          : saveToDeviceStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      savedToDeviceTitle: freezed == savedToDeviceTitle
          ? _value.savedToDeviceTitle
          : savedToDeviceTitle // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$DownloadStateImpl implements _DownloadState {
  const _$DownloadStateImpl(
      {required this.fetchOptionsStatus,
      required this.fetchDownloadsStatus,
      this.downloadOptions,
      required final List<DownloadItem> allDownloads,
      required final List<DownloadItem> completedDownloads,
      required final List<DownloadItem> activeDownloads,
      required final List<DownloadItem> pendingDownloads,
      this.errorMessage,
      this.failedDownloadTitle,
      required this.saveToDeviceStatus,
      this.savedToDeviceTitle})
      : _allDownloads = allDownloads,
        _completedDownloads = completedDownloads,
        _activeDownloads = activeDownloads,
        _pendingDownloads = pendingDownloads;

  /// Status of fetching download options
  @override
  final ApiStatus fetchOptionsStatus;

  /// Status of fetching downloads list
  @override
  final ApiStatus fetchDownloadsStatus;

  /// Available download options for current video
  @override
  final DownloadOptions? downloadOptions;

  /// All downloads
  final List<DownloadItem> _allDownloads;

  /// All downloads
  @override
  List<DownloadItem> get allDownloads {
    if (_allDownloads is EqualUnmodifiableListView) return _allDownloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allDownloads);
  }

  /// Completed downloads
  final List<DownloadItem> _completedDownloads;

  /// Completed downloads
  @override
  List<DownloadItem> get completedDownloads {
    if (_completedDownloads is EqualUnmodifiableListView)
      return _completedDownloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_completedDownloads);
  }

  /// Active (currently downloading) downloads
  final List<DownloadItem> _activeDownloads;

  /// Active (currently downloading) downloads
  @override
  List<DownloadItem> get activeDownloads {
    if (_activeDownloads is EqualUnmodifiableListView) return _activeDownloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeDownloads);
  }

  /// Pending or paused downloads
  final List<DownloadItem> _pendingDownloads;

  /// Pending or paused downloads
  @override
  List<DownloadItem> get pendingDownloads {
    if (_pendingDownloads is EqualUnmodifiableListView)
      return _pendingDownloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingDownloads);
  }

  /// Error message if any
  @override
  final String? errorMessage;

  /// Title of the failed download (for snackbar display)
  @override
  final String? failedDownloadTitle;

  /// Save to device operation status
  @override
  final ApiStatus saveToDeviceStatus;

  /// Title of the file that was saved to device (for success message)
  @override
  final String? savedToDeviceTitle;

  @override
  String toString() {
    return 'DownloadState(fetchOptionsStatus: $fetchOptionsStatus, fetchDownloadsStatus: $fetchDownloadsStatus, downloadOptions: $downloadOptions, allDownloads: $allDownloads, completedDownloads: $completedDownloads, activeDownloads: $activeDownloads, pendingDownloads: $pendingDownloads, errorMessage: $errorMessage, failedDownloadTitle: $failedDownloadTitle, saveToDeviceStatus: $saveToDeviceStatus, savedToDeviceTitle: $savedToDeviceTitle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadStateImpl &&
            (identical(other.fetchOptionsStatus, fetchOptionsStatus) ||
                other.fetchOptionsStatus == fetchOptionsStatus) &&
            (identical(other.fetchDownloadsStatus, fetchDownloadsStatus) ||
                other.fetchDownloadsStatus == fetchDownloadsStatus) &&
            (identical(other.downloadOptions, downloadOptions) ||
                other.downloadOptions == downloadOptions) &&
            const DeepCollectionEquality()
                .equals(other._allDownloads, _allDownloads) &&
            const DeepCollectionEquality()
                .equals(other._completedDownloads, _completedDownloads) &&
            const DeepCollectionEquality()
                .equals(other._activeDownloads, _activeDownloads) &&
            const DeepCollectionEquality()
                .equals(other._pendingDownloads, _pendingDownloads) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.failedDownloadTitle, failedDownloadTitle) ||
                other.failedDownloadTitle == failedDownloadTitle) &&
            (identical(other.saveToDeviceStatus, saveToDeviceStatus) ||
                other.saveToDeviceStatus == saveToDeviceStatus) &&
            (identical(other.savedToDeviceTitle, savedToDeviceTitle) ||
                other.savedToDeviceTitle == savedToDeviceTitle));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      fetchOptionsStatus,
      fetchDownloadsStatus,
      downloadOptions,
      const DeepCollectionEquality().hash(_allDownloads),
      const DeepCollectionEquality().hash(_completedDownloads),
      const DeepCollectionEquality().hash(_activeDownloads),
      const DeepCollectionEquality().hash(_pendingDownloads),
      errorMessage,
      failedDownloadTitle,
      saveToDeviceStatus,
      savedToDeviceTitle);

  /// Create a copy of DownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadStateImplCopyWith<_$DownloadStateImpl> get copyWith =>
      __$$DownloadStateImplCopyWithImpl<_$DownloadStateImpl>(this, _$identity);
}

abstract class _DownloadState implements DownloadState {
  const factory _DownloadState(
      {required final ApiStatus fetchOptionsStatus,
      required final ApiStatus fetchDownloadsStatus,
      final DownloadOptions? downloadOptions,
      required final List<DownloadItem> allDownloads,
      required final List<DownloadItem> completedDownloads,
      required final List<DownloadItem> activeDownloads,
      required final List<DownloadItem> pendingDownloads,
      final String? errorMessage,
      final String? failedDownloadTitle,
      required final ApiStatus saveToDeviceStatus,
      final String? savedToDeviceTitle}) = _$DownloadStateImpl;

  /// Status of fetching download options
  @override
  ApiStatus get fetchOptionsStatus;

  /// Status of fetching downloads list
  @override
  ApiStatus get fetchDownloadsStatus;

  /// Available download options for current video
  @override
  DownloadOptions? get downloadOptions;

  /// All downloads
  @override
  List<DownloadItem> get allDownloads;

  /// Completed downloads
  @override
  List<DownloadItem> get completedDownloads;

  /// Active (currently downloading) downloads
  @override
  List<DownloadItem> get activeDownloads;

  /// Pending or paused downloads
  @override
  List<DownloadItem> get pendingDownloads;

  /// Error message if any
  @override
  String? get errorMessage;

  /// Title of the failed download (for snackbar display)
  @override
  String? get failedDownloadTitle;

  /// Save to device operation status
  @override
  ApiStatus get saveToDeviceStatus;

  /// Title of the file that was saved to device (for success message)
  @override
  String? get savedToDeviceTitle;

  /// Create a copy of DownloadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DownloadStateImplCopyWith<_$DownloadStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

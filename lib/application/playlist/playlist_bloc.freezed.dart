// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playlist_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PlaylistEvent {
  String get playlistId => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String playlistId, String serviceType)
        getPlaylistData,
    required TResult Function(String playlistId, String? nextPage)
        getMorePlaylistVideos,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String playlistId, String serviceType)? getPlaylistData,
    TResult? Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String playlistId, String serviceType)? getPlaylistData,
    TResult Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GetPlaylistData value) getPlaylistData,
    required TResult Function(GetMorePlaylistVideos value)
        getMorePlaylistVideos,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GetPlaylistData value)? getPlaylistData,
    TResult? Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GetPlaylistData value)? getPlaylistData,
    TResult Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlaylistEventCopyWith<PlaylistEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaylistEventCopyWith<$Res> {
  factory $PlaylistEventCopyWith(
          PlaylistEvent value, $Res Function(PlaylistEvent) then) =
      _$PlaylistEventCopyWithImpl<$Res, PlaylistEvent>;
  @useResult
  $Res call({String playlistId});
}

/// @nodoc
class _$PlaylistEventCopyWithImpl<$Res, $Val extends PlaylistEvent>
    implements $PlaylistEventCopyWith<$Res> {
  _$PlaylistEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playlistId = null,
  }) {
    return _then(_value.copyWith(
      playlistId: null == playlistId
          ? _value.playlistId
          : playlistId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GetPlaylistDataImplCopyWith<$Res>
    implements $PlaylistEventCopyWith<$Res> {
  factory _$$GetPlaylistDataImplCopyWith(_$GetPlaylistDataImpl value,
          $Res Function(_$GetPlaylistDataImpl) then) =
      __$$GetPlaylistDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String playlistId, String serviceType});
}

/// @nodoc
class __$$GetPlaylistDataImplCopyWithImpl<$Res>
    extends _$PlaylistEventCopyWithImpl<$Res, _$GetPlaylistDataImpl>
    implements _$$GetPlaylistDataImplCopyWith<$Res> {
  __$$GetPlaylistDataImplCopyWithImpl(
      _$GetPlaylistDataImpl _value, $Res Function(_$GetPlaylistDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playlistId = null,
    Object? serviceType = null,
  }) {
    return _then(_$GetPlaylistDataImpl(
      playlistId: null == playlistId
          ? _value.playlistId
          : playlistId // ignore: cast_nullable_to_non_nullable
              as String,
      serviceType: null == serviceType
          ? _value.serviceType
          : serviceType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$GetPlaylistDataImpl implements GetPlaylistData {
  const _$GetPlaylistDataImpl(
      {required this.playlistId, required this.serviceType});

  @override
  final String playlistId;
  @override
  final String serviceType;

  @override
  String toString() {
    return 'PlaylistEvent.getPlaylistData(playlistId: $playlistId, serviceType: $serviceType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GetPlaylistDataImpl &&
            (identical(other.playlistId, playlistId) ||
                other.playlistId == playlistId) &&
            (identical(other.serviceType, serviceType) ||
                other.serviceType == serviceType));
  }

  @override
  int get hashCode => Object.hash(runtimeType, playlistId, serviceType);

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GetPlaylistDataImplCopyWith<_$GetPlaylistDataImpl> get copyWith =>
      __$$GetPlaylistDataImplCopyWithImpl<_$GetPlaylistDataImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String playlistId, String serviceType)
        getPlaylistData,
    required TResult Function(String playlistId, String? nextPage)
        getMorePlaylistVideos,
  }) {
    return getPlaylistData(playlistId, serviceType);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String playlistId, String serviceType)? getPlaylistData,
    TResult? Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
  }) {
    return getPlaylistData?.call(playlistId, serviceType);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String playlistId, String serviceType)? getPlaylistData,
    TResult Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
    required TResult orElse(),
  }) {
    if (getPlaylistData != null) {
      return getPlaylistData(playlistId, serviceType);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GetPlaylistData value) getPlaylistData,
    required TResult Function(GetMorePlaylistVideos value)
        getMorePlaylistVideos,
  }) {
    return getPlaylistData(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GetPlaylistData value)? getPlaylistData,
    TResult? Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
  }) {
    return getPlaylistData?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GetPlaylistData value)? getPlaylistData,
    TResult Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
    required TResult orElse(),
  }) {
    if (getPlaylistData != null) {
      return getPlaylistData(this);
    }
    return orElse();
  }
}

abstract class GetPlaylistData implements PlaylistEvent {
  const factory GetPlaylistData(
      {required final String playlistId,
      required final String serviceType}) = _$GetPlaylistDataImpl;

  @override
  String get playlistId;
  String get serviceType;

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GetPlaylistDataImplCopyWith<_$GetPlaylistDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GetMorePlaylistVideosImplCopyWith<$Res>
    implements $PlaylistEventCopyWith<$Res> {
  factory _$$GetMorePlaylistVideosImplCopyWith(
          _$GetMorePlaylistVideosImpl value,
          $Res Function(_$GetMorePlaylistVideosImpl) then) =
      __$$GetMorePlaylistVideosImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String playlistId, String? nextPage});
}

/// @nodoc
class __$$GetMorePlaylistVideosImplCopyWithImpl<$Res>
    extends _$PlaylistEventCopyWithImpl<$Res, _$GetMorePlaylistVideosImpl>
    implements _$$GetMorePlaylistVideosImplCopyWith<$Res> {
  __$$GetMorePlaylistVideosImplCopyWithImpl(_$GetMorePlaylistVideosImpl _value,
      $Res Function(_$GetMorePlaylistVideosImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playlistId = null,
    Object? nextPage = freezed,
  }) {
    return _then(_$GetMorePlaylistVideosImpl(
      playlistId: null == playlistId
          ? _value.playlistId
          : playlistId // ignore: cast_nullable_to_non_nullable
              as String,
      nextPage: freezed == nextPage
          ? _value.nextPage
          : nextPage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$GetMorePlaylistVideosImpl implements GetMorePlaylistVideos {
  const _$GetMorePlaylistVideosImpl({required this.playlistId, this.nextPage});

  @override
  final String playlistId;
  @override
  final String? nextPage;

  @override
  String toString() {
    return 'PlaylistEvent.getMorePlaylistVideos(playlistId: $playlistId, nextPage: $nextPage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GetMorePlaylistVideosImpl &&
            (identical(other.playlistId, playlistId) ||
                other.playlistId == playlistId) &&
            (identical(other.nextPage, nextPage) ||
                other.nextPage == nextPage));
  }

  @override
  int get hashCode => Object.hash(runtimeType, playlistId, nextPage);

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GetMorePlaylistVideosImplCopyWith<_$GetMorePlaylistVideosImpl>
      get copyWith => __$$GetMorePlaylistVideosImplCopyWithImpl<
          _$GetMorePlaylistVideosImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String playlistId, String serviceType)
        getPlaylistData,
    required TResult Function(String playlistId, String? nextPage)
        getMorePlaylistVideos,
  }) {
    return getMorePlaylistVideos(playlistId, nextPage);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String playlistId, String serviceType)? getPlaylistData,
    TResult? Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
  }) {
    return getMorePlaylistVideos?.call(playlistId, nextPage);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String playlistId, String serviceType)? getPlaylistData,
    TResult Function(String playlistId, String? nextPage)?
        getMorePlaylistVideos,
    required TResult orElse(),
  }) {
    if (getMorePlaylistVideos != null) {
      return getMorePlaylistVideos(playlistId, nextPage);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GetPlaylistData value) getPlaylistData,
    required TResult Function(GetMorePlaylistVideos value)
        getMorePlaylistVideos,
  }) {
    return getMorePlaylistVideos(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GetPlaylistData value)? getPlaylistData,
    TResult? Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
  }) {
    return getMorePlaylistVideos?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GetPlaylistData value)? getPlaylistData,
    TResult Function(GetMorePlaylistVideos value)? getMorePlaylistVideos,
    required TResult orElse(),
  }) {
    if (getMorePlaylistVideos != null) {
      return getMorePlaylistVideos(this);
    }
    return orElse();
  }
}

abstract class GetMorePlaylistVideos implements PlaylistEvent {
  const factory GetMorePlaylistVideos(
      {required final String playlistId,
      final String? nextPage}) = _$GetMorePlaylistVideosImpl;

  @override
  String get playlistId;
  String? get nextPage;

  /// Create a copy of PlaylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GetMorePlaylistVideosImplCopyWith<_$GetMorePlaylistVideosImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlaylistState {
  ApiStatus get fetchStatus => throw _privateConstructorUsedError;
  ApiStatus get moreFetchStatus => throw _privateConstructorUsedError;
  bool get isMoreFetchCompleted => throw _privateConstructorUsedError;
  PlaylistResp? get pipedPlaylistResp => throw _privateConstructorUsedError;
  InvidiousPlaylistResp? get invidiousPlaylistResp =>
      throw _privateConstructorUsedError;
  NewPipePlaylistResp? get newpipePlaylistResp =>
      throw _privateConstructorUsedError;

  /// Create a copy of PlaylistState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlaylistStateCopyWith<PlaylistState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaylistStateCopyWith<$Res> {
  factory $PlaylistStateCopyWith(
          PlaylistState value, $Res Function(PlaylistState) then) =
      _$PlaylistStateCopyWithImpl<$Res, PlaylistState>;
  @useResult
  $Res call(
      {ApiStatus fetchStatus,
      ApiStatus moreFetchStatus,
      bool isMoreFetchCompleted,
      PlaylistResp? pipedPlaylistResp,
      InvidiousPlaylistResp? invidiousPlaylistResp,
      NewPipePlaylistResp? newpipePlaylistResp});
}

/// @nodoc
class _$PlaylistStateCopyWithImpl<$Res, $Val extends PlaylistState>
    implements $PlaylistStateCopyWith<$Res> {
  _$PlaylistStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlaylistState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fetchStatus = null,
    Object? moreFetchStatus = null,
    Object? isMoreFetchCompleted = null,
    Object? pipedPlaylistResp = freezed,
    Object? invidiousPlaylistResp = freezed,
    Object? newpipePlaylistResp = freezed,
  }) {
    return _then(_value.copyWith(
      fetchStatus: null == fetchStatus
          ? _value.fetchStatus
          : fetchStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      moreFetchStatus: null == moreFetchStatus
          ? _value.moreFetchStatus
          : moreFetchStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      isMoreFetchCompleted: null == isMoreFetchCompleted
          ? _value.isMoreFetchCompleted
          : isMoreFetchCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      pipedPlaylistResp: freezed == pipedPlaylistResp
          ? _value.pipedPlaylistResp
          : pipedPlaylistResp // ignore: cast_nullable_to_non_nullable
              as PlaylistResp?,
      invidiousPlaylistResp: freezed == invidiousPlaylistResp
          ? _value.invidiousPlaylistResp
          : invidiousPlaylistResp // ignore: cast_nullable_to_non_nullable
              as InvidiousPlaylistResp?,
      newpipePlaylistResp: freezed == newpipePlaylistResp
          ? _value.newpipePlaylistResp
          : newpipePlaylistResp // ignore: cast_nullable_to_non_nullable
              as NewPipePlaylistResp?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlaylistStateImplCopyWith<$Res>
    implements $PlaylistStateCopyWith<$Res> {
  factory _$$PlaylistStateImplCopyWith(
          _$PlaylistStateImpl value, $Res Function(_$PlaylistStateImpl) then) =
      __$$PlaylistStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ApiStatus fetchStatus,
      ApiStatus moreFetchStatus,
      bool isMoreFetchCompleted,
      PlaylistResp? pipedPlaylistResp,
      InvidiousPlaylistResp? invidiousPlaylistResp,
      NewPipePlaylistResp? newpipePlaylistResp});
}

/// @nodoc
class __$$PlaylistStateImplCopyWithImpl<$Res>
    extends _$PlaylistStateCopyWithImpl<$Res, _$PlaylistStateImpl>
    implements _$$PlaylistStateImplCopyWith<$Res> {
  __$$PlaylistStateImplCopyWithImpl(
      _$PlaylistStateImpl _value, $Res Function(_$PlaylistStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlaylistState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fetchStatus = null,
    Object? moreFetchStatus = null,
    Object? isMoreFetchCompleted = null,
    Object? pipedPlaylistResp = freezed,
    Object? invidiousPlaylistResp = freezed,
    Object? newpipePlaylistResp = freezed,
  }) {
    return _then(_$PlaylistStateImpl(
      fetchStatus: null == fetchStatus
          ? _value.fetchStatus
          : fetchStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      moreFetchStatus: null == moreFetchStatus
          ? _value.moreFetchStatus
          : moreFetchStatus // ignore: cast_nullable_to_non_nullable
              as ApiStatus,
      isMoreFetchCompleted: null == isMoreFetchCompleted
          ? _value.isMoreFetchCompleted
          : isMoreFetchCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      pipedPlaylistResp: freezed == pipedPlaylistResp
          ? _value.pipedPlaylistResp
          : pipedPlaylistResp // ignore: cast_nullable_to_non_nullable
              as PlaylistResp?,
      invidiousPlaylistResp: freezed == invidiousPlaylistResp
          ? _value.invidiousPlaylistResp
          : invidiousPlaylistResp // ignore: cast_nullable_to_non_nullable
              as InvidiousPlaylistResp?,
      newpipePlaylistResp: freezed == newpipePlaylistResp
          ? _value.newpipePlaylistResp
          : newpipePlaylistResp // ignore: cast_nullable_to_non_nullable
              as NewPipePlaylistResp?,
    ));
  }
}

/// @nodoc

class _$PlaylistStateImpl implements _PlaylistState {
  _$PlaylistStateImpl(
      {required this.fetchStatus,
      required this.moreFetchStatus,
      required this.isMoreFetchCompleted,
      this.pipedPlaylistResp,
      this.invidiousPlaylistResp,
      this.newpipePlaylistResp});

  @override
  final ApiStatus fetchStatus;
  @override
  final ApiStatus moreFetchStatus;
  @override
  final bool isMoreFetchCompleted;
  @override
  final PlaylistResp? pipedPlaylistResp;
  @override
  final InvidiousPlaylistResp? invidiousPlaylistResp;
  @override
  final NewPipePlaylistResp? newpipePlaylistResp;

  @override
  String toString() {
    return 'PlaylistState(fetchStatus: $fetchStatus, moreFetchStatus: $moreFetchStatus, isMoreFetchCompleted: $isMoreFetchCompleted, pipedPlaylistResp: $pipedPlaylistResp, invidiousPlaylistResp: $invidiousPlaylistResp, newpipePlaylistResp: $newpipePlaylistResp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlaylistStateImpl &&
            (identical(other.fetchStatus, fetchStatus) ||
                other.fetchStatus == fetchStatus) &&
            (identical(other.moreFetchStatus, moreFetchStatus) ||
                other.moreFetchStatus == moreFetchStatus) &&
            (identical(other.isMoreFetchCompleted, isMoreFetchCompleted) ||
                other.isMoreFetchCompleted == isMoreFetchCompleted) &&
            (identical(other.pipedPlaylistResp, pipedPlaylistResp) ||
                other.pipedPlaylistResp == pipedPlaylistResp) &&
            (identical(other.invidiousPlaylistResp, invidiousPlaylistResp) ||
                other.invidiousPlaylistResp == invidiousPlaylistResp) &&
            (identical(other.newpipePlaylistResp, newpipePlaylistResp) ||
                other.newpipePlaylistResp == newpipePlaylistResp));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      fetchStatus,
      moreFetchStatus,
      isMoreFetchCompleted,
      pipedPlaylistResp,
      invidiousPlaylistResp,
      newpipePlaylistResp);

  /// Create a copy of PlaylistState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlaylistStateImplCopyWith<_$PlaylistStateImpl> get copyWith =>
      __$$PlaylistStateImplCopyWithImpl<_$PlaylistStateImpl>(this, _$identity);
}

abstract class _PlaylistState implements PlaylistState {
  factory _PlaylistState(
          {required final ApiStatus fetchStatus,
          required final ApiStatus moreFetchStatus,
          required final bool isMoreFetchCompleted,
          final PlaylistResp? pipedPlaylistResp,
          final InvidiousPlaylistResp? invidiousPlaylistResp,
          final NewPipePlaylistResp? newpipePlaylistResp}) =
      _$PlaylistStateImpl;

  @override
  ApiStatus get fetchStatus;
  @override
  ApiStatus get moreFetchStatus;
  @override
  bool get isMoreFetchCompleted;
  @override
  PlaylistResp? get pipedPlaylistResp;
  @override
  InvidiousPlaylistResp? get invidiousPlaylistResp;
  @override
  NewPipePlaylistResp? get newpipePlaylistResp;

  /// Create a copy of PlaylistState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlaylistStateImplCopyWith<_$PlaylistStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

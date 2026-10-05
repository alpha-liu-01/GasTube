part of 'playlist_bloc.dart';

@freezed
class PlaylistState with _$PlaylistState {
  factory PlaylistState({
    required ApiStatus fetchStatus,
    required ApiStatus moreFetchStatus,
    required bool isMoreFetchCompleted,
    PlaylistResp? pipedPlaylistResp,
    InvidiousPlaylistResp? invidiousPlaylistResp,
    NewPipePlaylistResp? newpipePlaylistResp,
  }) = _PlaylistState;

  factory PlaylistState.initialize() => PlaylistState(
        fetchStatus: ApiStatus.initial,
        moreFetchStatus: ApiStatus.initial,
        isMoreFetchCompleted: false,
        pipedPlaylistResp: null,
        invidiousPlaylistResp: null,
        newpipePlaylistResp: null,
      );
}

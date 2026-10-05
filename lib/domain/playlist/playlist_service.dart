import 'package:dartz/dartz.dart';
import 'package:fluxtube/domain/core/failure/main_failure.dart';
import 'package:fluxtube/domain/playlist/models/invidious/invidious_playlist_resp.dart';
import 'package:fluxtube/domain/playlist/models/newpipe/newpipe_playlist_resp.dart';
import 'package:fluxtube/domain/playlist/models/piped/playlist_resp.dart';

abstract class PlaylistService {
  /// Fetch playlist data from Piped API
  Future<Either<MainFailure, PlaylistResp>> getPlaylistData({
    required String playlistId,
  });

  /// Fetch more playlist videos from Piped API (pagination)
  Future<Either<MainFailure, PlaylistResp>> getMorePlaylistVideos({
    required String playlistId,
    required String nextPage,
  });

  /// Fetch playlist data from Invidious API
  Future<Either<MainFailure, InvidiousPlaylistResp>> getInvidiousPlaylistData({
    required String playlistId,
  });

  /// Fetch a YouTube playlist through NewPipe Extractor.
  Future<Either<MainFailure, NewPipePlaylistResp>> getNewPipePlaylistData({
    required String playlistId,
  });

  /// Fetch the next page of a NewPipe playlist.
  Future<Either<MainFailure, NewPipePlaylistResp>> getMoreNewPipePlaylistVideos({
    required String playlistId,
    required String nextPage,
  });
}

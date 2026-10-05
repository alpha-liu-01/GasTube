import 'package:json_annotation/json_annotation.dart';
import 'newpipe_stream.dart';
import 'newpipe_related.dart';
import 'newpipe_subtitle.dart';

part 'newpipe_watch_resp.g.dart';

@JsonSerializable()
class NewPipeWatchResp {
  final String? id;
  final String? title;
  final String? description;
  final String? uploaderName;
  final String? uploaderUrl;
  final String? uploaderAvatarUrl;
  final bool? uploaderVerified;
  final int? uploaderSubscriberCount;
  final String? thumbnailUrl;
  final int? duration;
  final int? viewCount;
  final int? likeCount;
  final int? dislikeCount;
  final String? uploadDate;
  final String? textualUploadDate;
  final String? category;
  final List<String>? tags;
  final bool? isLive;
  final String? hlsUrl;
  final String? dashMpdUrl;
  final List<NewPipeAudioStream>? audioStreams;
  final List<NewPipeVideoStream>? videoStreams;
  final List<NewPipeVideoStream>? videoOnlyStreams;
  final List<NewPipeRelatedStream>? relatedStreams;
  final List<NewPipeSubtitle>? subtitles;

  NewPipeWatchResp({
    this.id,
    this.title,
    this.description,
    this.uploaderName,
    this.uploaderUrl,
    this.uploaderAvatarUrl,
    this.uploaderVerified,
    this.uploaderSubscriberCount,
    this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.likeCount,
    this.dislikeCount,
    this.uploadDate,
    this.textualUploadDate,
    this.category,
    this.tags,
    this.isLive,
    this.hlsUrl,
    this.dashMpdUrl,
    this.audioStreams,
    this.videoStreams,
    this.videoOnlyStreams,
    this.relatedStreams,
    this.subtitles,
  });

  factory NewPipeWatchResp.fromJson(Map<String, dynamic> json) =>
      _$NewPipeWatchRespFromJson(json);

  Map<String, dynamic> toJson() => _$NewPipeWatchRespToJson(this);

  /// Kept from the hardware-decode probe. The Ubuntu Touch player no longer
  /// calls this; H.264, VP9, and AV1 all stay in the quality list.
  NewPipeWatchResp h264VideoOnly() {
    final live = isLive == true;
    return NewPipeWatchResp(
      id: id,
      title: title,
      description: description,
      uploaderName: uploaderName,
      uploaderUrl: uploaderUrl,
      uploaderAvatarUrl: uploaderAvatarUrl,
      uploaderVerified: uploaderVerified,
      uploaderSubscriberCount: uploaderSubscriberCount,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      viewCount: viewCount,
      likeCount: likeCount,
      dislikeCount: dislikeCount,
      uploadDate: uploadDate,
      textualUploadDate: textualUploadDate,
      category: category,
      tags: tags,
      isLive: isLive,
      hlsUrl: live ? hlsUrl : null,
      dashMpdUrl: live ? dashMpdUrl : null,
      audioStreams: audioStreams,
      videoStreams: videoStreams?.where(_isH264Video).toList(),
      videoOnlyStreams: videoOnlyStreams?.where(_isH264Video).toList(),
      relatedStreams: relatedStreams,
      subtitles: subtitles,
    );
  }
}

bool _isH264Video(NewPipeVideoStream stream) {
  final codec = (stream.codec ?? '').toLowerCase();
  if (codec.isNotEmpty) {
    return codec.startsWith('avc1') ||
        codec.startsWith('avc3') ||
        codec.contains('h264');
  }
  final format = (stream.format ?? '').toUpperCase();
  return format == 'MPEG_4' || format == 'MP4';
}

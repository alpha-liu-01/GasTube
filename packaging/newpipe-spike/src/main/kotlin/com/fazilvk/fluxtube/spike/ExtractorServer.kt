package com.fazilvk.fluxtube.spike

import com.fazilvk.fluxtube.newpipe.FluxTubeDownloader
import com.google.gson.GsonBuilder
import com.google.gson.JsonObject
import org.schabi.newpipe.extractor.Image
import org.schabi.newpipe.extractor.InfoItem
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.Page
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.channel.ChannelInfo
import org.schabi.newpipe.extractor.channel.ChannelInfoItem
import org.schabi.newpipe.extractor.comments.CommentsInfo
import org.schabi.newpipe.extractor.kiosk.KioskInfo
import org.schabi.newpipe.extractor.localization.ContentCountry
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.playlist.PlaylistInfo
import org.schabi.newpipe.extractor.playlist.PlaylistInfoItem
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.services.youtube.YoutubeJavaScriptPlayerManager
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import org.schabi.newpipe.extractor.stream.VideoStream
import java.util.Base64
import java.util.concurrent.ConcurrentHashMap

/**
 * Line-delimited JSON server for the desktop NewPipe sidecar.
 * Request:  {"id":1,"method":"getStreamInfo","args":{"id":"..."}}
 * Success:  {"id":1,"ok":true,"result":"<json string the Android channel returns>"}
 * Failure:  {"id":1,"ok":false,"code":"...","message":"..."}
 */
object ExtractorServer {
    private val gson = GsonBuilder().serializeNulls().create()
    private val streamInfoCache = ConcurrentHashMap<String, CachedStreamInfo>()
    private const val cacheTtlMs = 5 * 60 * 1000L

    fun serve() {
        val reader = System.`in`.bufferedReader(Charsets.UTF_8)
        while (true) {
            val line = reader.readLine() ?: break
            if (line.isBlank()) continue
            var id: Any? = null
            try {
                val request = gson.fromJson(line, JsonObject::class.java)
                id = request.get("id")
                val method = request.get("method")?.asString
                    ?: throw ArgException("method is required")
                val args = request.getAsJsonObject("args") ?: JsonObject()
                val result = dispatch(method, args)
                reply(id, ok = true, result = result)
            } catch (e: ArgException) {
                reply(id, ok = false, code = "INVALID_ARGUMENT", message = e.message)
            } catch (e: Exception) {
                System.err.println("NewPipe $line failed: ${e.message}")
                reply(
                    id,
                    ok = false,
                    code = "EXTRACTION_ERROR",
                    message = e.message ?: "Failed",
                )
            }
        }
    }

    private fun dispatch(method: String, args: JsonObject): String {
        return when (method) {
            "isAvailable" -> "true"
            "getStreamInfo" -> streamInfoJson(required(args, "id"), includeRelated = true)
            "getStreamInfoFast" -> streamInfoJson(required(args, "id"), includeRelated = false)
            "forgetStreamInfo" -> {
                streamInfoCache.remove(required(args, "id"))
                "true"
            }
            "getTrending" -> trending(optional(args, "region") ?: "US")
            "search" -> search(
                required(args, "query"),
                optional(args, "filter") ?: "all",
                optional(args, "nextPage"),
            )
            "getSearchSuggestions" -> suggestions(required(args, "query"))
            "getChannel" -> channel(required(args, "id"))
            "getChannelTab" -> channelTab(
                required(args, "url"),
                optional(args, "id"),
                stringList(args, "contentFilters"),
                optional(args, "nextPage"),
            )
            "getComments" -> comments(required(args, "id"))
            "getMoreComments" -> moreComments(required(args, "id"), required(args, "nextPage"))
            "getCommentReplies" -> moreComments(required(args, "id"), required(args, "repliesPage"))
            "getPlaylist" -> playlist(required(args, "id"))
            "getMorePlaylist" -> morePlaylist(required(args, "id"), required(args, "nextPage"))
            else -> throw ArgException("Unknown method $method")
        }
    }

    private fun streamInfoJson(videoId: String, includeRelated: Boolean): String {
        val info = cachedStreamInfo(videoId)
        val bestThumbnail = info.thumbnails.maxByOrNull { it.width * it.height }?.url
            ?: info.thumbnails.lastOrNull()?.url
        val response = linkedMapOf<String, Any?>(
            "id" to info.id,
            "title" to info.name,
            "uploaderName" to info.uploaderName,
            "uploaderUrl" to info.uploaderUrl,
            "uploaderAvatarUrl" to info.uploaderAvatars.firstOrNull()?.url,
            "uploaderVerified" to info.isUploaderVerified,
            "uploaderSubscriberCount" to info.uploaderSubscriberCount,
            "thumbnailUrl" to bestThumbnail,
            "duration" to info.duration,
            "viewCount" to info.viewCount,
            "likeCount" to info.likeCount,
            "dislikeCount" to info.dislikeCount,
            "uploadDate" to info.uploadDate?.offsetDateTime()?.toString(),
            "textualUploadDate" to info.textualUploadDate,
            "isLive" to (info.streamType.name == "LIVE_STREAM"),
            "hlsUrl" to info.hlsUrl,
            "dashMpdUrl" to info.dashMpdUrl,
            "audioStreams" to info.audioStreams.map { mapAudioStream(it) },
            "videoStreams" to info.videoStreams.map { mapVideoStream(it) },
            "videoOnlyStreams" to info.videoOnlyStreams.map { mapVideoStream(it) },
            "subtitles" to info.subtitles.map { subtitle ->
                mapOf(
                    "url" to subtitle.content,
                    "mimeType" to subtitle.format?.mimeType,
                    "languageCode" to subtitle.languageTag,
                    "autoGenerated" to subtitle.isAutoGenerated,
                )
            },
        )
        if (includeRelated) {
            response["description"] = info.description?.content
            response["category"] = info.category
            response["tags"] = info.tags?.toList()
            response["relatedStreams"] = info.relatedItems.take(20).map { mapInfoItem(it) }
        }
        return gson.toJson(response)
    }

    private fun trending(region: String): String {
        val service = ServiceList.YouTube
        val kiosk = service.kioskList.defaultKioskExtractor
        NewPipe.setupLocalization(Localization.DEFAULT, ContentCountry(region))
        val kioskInfo = KioskInfo.getInfo(service, kiosk.url)
        return gson.toJson(
            mapOf(
                "videos" to kioskInfo.relatedItems.map { mapInfoItem(it) },
                "nextPage" to kioskInfo.nextPage?.url,
            ),
        )
    }

    private fun search(query: String, filter: String, nextPageJson: String?): String {
        val service = ServiceList.YouTube
        val contentFilters = when (filter) {
            "videos" -> listOf("videos")
            "channels" -> listOf("channels")
            "playlists" -> listOf("playlists")
            "music_songs" -> listOf("music_songs")
            else -> emptyList()
        }
        val handler = service.searchQHFactory.fromQuery(query, contentFilters, "")
        val payload = if (nextPageJson != null) {
            val more = SearchInfo.getMoreItems(service, handler, deserializePage(nextPageJson))
            mapOf(
                "items" to more.items.map { mapInfoItem(it) },
                "nextPage" to serializePage(more.nextPage),
            )
        } else {
            val info = SearchInfo.getInfo(service, handler)
            mapOf(
                "items" to info.relatedItems.map { mapInfoItem(it) },
                "nextPage" to serializePage(info.nextPage),
                "searchSuggestion" to info.searchSuggestion,
                "isCorrectedSearch" to info.isCorrectedSearch,
            )
        }
        return gson.toJson(payload)
    }

    private fun suggestions(query: String): String {
        val suggestions = ServiceList.YouTube.suggestionExtractor.suggestionList(query)
        return gson.toJson(suggestions)
    }

    private fun channel(channelId: String): String {
        val url = if (channelId.startsWith("http")) {
            channelId
        } else {
            "https://www.youtube.com/channel/$channelId"
        }
        val channelInfo = ChannelInfo.getInfo(ServiceList.YouTube, url)
        var initialVideos: List<Map<String, Any?>> = emptyList()
        var videosNextPage: String? = null
        if (channelInfo.tabs.isNotEmpty()) {
            try {
                val videosTab = channelInfo.tabs.find { tab ->
                    tab.contentFilters.any { it.contains("videos", ignoreCase = true) }
                } ?: channelInfo.tabs.firstOrNull()
                if (videosTab != null) {
                    val tabExtractor = ServiceList.YouTube.getChannelTabExtractor(videosTab)
                    tabExtractor.fetchPage()
                    initialVideos = tabExtractor.initialPage.items.map { mapInfoItem(it) }
                    videosNextPage = serializePage(tabExtractor.initialPage.nextPage)
                }
            } catch (tabError: Exception) {
                System.err.println("NewPipe channel tab failed: ${tabError.message}")
            }
        }
        return gson.toJson(
            mapOf(
                "id" to channelInfo.id,
                "name" to channelInfo.name,
                "description" to channelInfo.description,
                "avatarUrl" to bestImage(channelInfo.avatars),
                "bannerUrl" to bestImage(channelInfo.banners),
                "subscriberCount" to channelInfo.subscriberCount,
                "isVerified" to channelInfo.isVerified,
                "videos" to initialVideos,
                "nextPage" to videosNextPage,
                "tabs" to channelInfo.tabs.map { tab ->
                    mapOf(
                        "name" to tab.contentFilters.firstOrNull()?.lowercase(),
                        "url" to tab.url,
                        "id" to tab.id,
                        "contentFilters" to tab.contentFilters,
                    )
                },
            ),
        )
    }

    private fun channelTab(
        tabUrl: String,
        tabId: String?,
        contentFilters: List<String>,
        nextPageJson: String?,
    ): String {
        val linkHandler = ServiceList.YouTube.channelTabLHFactory.fromQuery(
            tabId ?: tabUrl,
            contentFilters,
            "",
        )
        val tabExtractor = ServiceList.YouTube.getChannelTabExtractor(linkHandler)
        val payload = if (nextPageJson != null) {
            val more = tabExtractor.getPage(deserializePage(nextPageJson))
            mapOf(
                "videos" to more.items.map { mapInfoItem(it) },
                "nextPage" to serializePage(more.nextPage),
            )
        } else {
            tabExtractor.fetchPage()
            mapOf(
                "videos" to tabExtractor.initialPage.items.map { mapInfoItem(it) },
                "nextPage" to serializePage(tabExtractor.initialPage.nextPage),
            )
        }
        return gson.toJson(payload)
    }

    private fun comments(videoId: String): String {
        val url = "https://www.youtube.com/watch?v=$videoId"
        val commentsInfo = CommentsInfo.getInfo(ServiceList.YouTube, url)
        return gson.toJson(
            mapOf(
                "comments" to commentsInfo.relatedItems.map { mapComment(it) },
                "nextPage" to serializePage(commentsInfo.nextPage),
                "commentCount" to commentsInfo.commentsCount,
                "isDisabled" to commentsInfo.isCommentsDisabled,
            ),
        )
    }

    private fun moreComments(videoId: String, pageJson: String): String {
        val url = "https://www.youtube.com/watch?v=$videoId"
        val more = CommentsInfo.getMoreItems(ServiceList.YouTube, url, deserializePage(pageJson))
        return gson.toJson(
            mapOf(
                "comments" to more.items.map { mapComment(it) },
                "nextPage" to serializePage(more.nextPage),
            ),
        )
    }

    private fun playlistUrl(idOrUrl: String): String {
        return if (idOrUrl.startsWith("http")) {
            idOrUrl
        } else {
            "https://www.youtube.com/playlist?list=$idOrUrl"
        }
    }

    private fun playlist(idOrUrl: String): String {
        val info = PlaylistInfo.getInfo(ServiceList.YouTube, playlistUrl(idOrUrl))
        val bestThumbnail = info.thumbnails.maxByOrNull { it.width * it.height }?.url
            ?: info.thumbnails.lastOrNull()?.url
        return gson.toJson(
            mapOf(
                "id" to info.id,
                "name" to info.name,
                "thumbnailUrl" to bestThumbnail,
                "uploaderName" to info.uploaderName,
                "uploaderUrl" to info.uploaderUrl,
                "uploaderAvatarUrl" to bestImage(info.uploaderAvatars),
                "streamCount" to info.streamCount,
                "videos" to info.relatedItems.map { mapInfoItem(it) },
                "nextPage" to serializePage(info.nextPage),
            ),
        )
    }

    private fun morePlaylist(idOrUrl: String, nextPageJson: String): String {
        val more = PlaylistInfo.getMoreItems(
            ServiceList.YouTube,
            playlistUrl(idOrUrl),
            deserializePage(nextPageJson),
        )
        return gson.toJson(
            mapOf(
                "videos" to more.items.map { mapInfoItem(it) },
                "nextPage" to serializePage(more.nextPage),
            ),
        )
    }

    private fun mapComment(comment: org.schabi.newpipe.extractor.comments.CommentsInfoItem) = mapOf(
        "id" to comment.commentId,
        "text" to comment.commentText?.content,
        "authorName" to comment.uploaderName,
        "authorUrl" to comment.uploaderUrl,
        "authorAvatarUrl" to bestImage(comment.uploaderAvatars),
        "authorVerified" to comment.isUploaderVerified,
        "likeCount" to comment.likeCount,
        "replyCount" to comment.replyCount,
        "isPinned" to comment.isPinned,
        "isEdited" to comment.isEdited,
        "isHearted" to comment.isHeartedByUploader,
        "uploadDate" to comment.textualUploadDate,
        "repliesPage" to serializePage(comment.replies),
    )

    private fun cachedStreamInfo(videoId: String): StreamInfo {
        val now = System.currentTimeMillis()
        val cached = streamInfoCache[videoId]
        if (cached != null && now - cached.timestampMs <= cacheTtlMs) {
            return cached.streamInfo
        }
        // One live video. Drop the previous id before the next extract allocates.
        streamInfoCache.clear()
        val info = StreamInfo.getInfo(
            ServiceList.YouTube,
            "https://www.youtube.com/watch?v=$videoId",
        )
        // URLs on `info` are already deobfuscated. The n-parameter map is only
        // reused inside that extract, and it has no cap.
        YoutubeJavaScriptPlayerManager.clearThrottlingParametersCache()
        streamInfoCache[videoId] = CachedStreamInfo(info, now)
        return info
    }

    private fun mapAudioStream(stream: AudioStream): Map<String, Any?> {
        val itagItem = stream.itagItem
        return mapOf(
            "url" to stream.content,
            "averageBitrate" to stream.averageBitrate,
            "format" to stream.format?.name,
            "mimeType" to stream.format?.mimeType,
            "codec" to stream.codec,
            "quality" to stream.quality,
            "id" to stream.id,
            "itag" to stream.itag,
            "initStart" to itagItem?.initStart,
            "initEnd" to itagItem?.initEnd,
            "indexStart" to itagItem?.indexStart,
            "indexEnd" to itagItem?.indexEnd,
            "contentLength" to itagItem?.contentLength,
            "bitrate" to itagItem?.bitrate,
            "approxDurationMs" to itagItem?.approxDurationMs,
            "audioChannels" to itagItem?.audioChannels,
            "sampleRate" to itagItem?.sampleRate,
            "audioTrackId" to stream.audioTrackId,
            "audioTrackName" to stream.audioTrackName,
            "audioTrackType" to stream.audioTrackType?.name,
            "audioLocale" to stream.audioLocale?.toLanguageTag(),
        )
    }

    private fun mapVideoStream(stream: VideoStream): Map<String, Any?> {
        val itagItem = stream.itagItem
        return mapOf(
            "url" to stream.content,
            "resolution" to stream.resolution,
            "format" to stream.format?.name,
            "mimeType" to stream.format?.mimeType,
            "codec" to stream.codec,
            "quality" to stream.quality,
            "width" to stream.width,
            "height" to stream.height,
            "fps" to stream.fps,
            "isVideoOnly" to stream.isVideoOnly,
            "id" to stream.id,
            "itag" to stream.itag,
            "initStart" to itagItem?.initStart,
            "initEnd" to itagItem?.initEnd,
            "indexStart" to itagItem?.indexStart,
            "indexEnd" to itagItem?.indexEnd,
            "contentLength" to itagItem?.contentLength,
            "bitrate" to itagItem?.bitrate,
            "approxDurationMs" to itagItem?.approxDurationMs,
        )
    }

    private fun mapInfoItem(item: InfoItem): Map<String, Any?> {
        val stream = item as? StreamInfoItem
        val channel = item as? ChannelInfoItem
        val playlist = item as? PlaylistInfoItem
        return mapOf(
            "url" to item.url,
            "name" to item.name,
            "thumbnailUrl" to thumbnailFor(item),
            "type" to item.infoType.name,
            "uploaderName" to stream?.uploaderName,
            "uploaderUrl" to stream?.uploaderUrl,
            "uploaderAvatarUrl" to stream?.uploaderAvatars?.let { bestImage(it) },
            "uploaderVerified" to stream?.isUploaderVerified,
            "duration" to stream?.duration,
            "viewCount" to stream?.viewCount,
            "uploadDate" to stream?.textualUploadDate,
            "isLive" to (stream?.streamType?.name == "LIVE_STREAM"),
            "isShort" to stream?.isShortFormContent,
            "contentAvailability" to stream?.contentAvailability?.name,
            "subscriberCount" to channel?.subscriberCount,
            "isVerified" to channel?.isVerified,
            "description" to channel?.description,
            "streamCount" to playlist?.streamCount,
            "playlistUploaderName" to playlist?.uploaderName,
            "playlistUploaderUrl" to playlist?.uploaderUrl,
        )
    }

    private fun thumbnailFor(item: InfoItem): String? {
        if (item is ChannelInfoItem && item.thumbnails.isNotEmpty()) {
            return bestImage(item.thumbnails)
        }
        if (item.thumbnails.isNotEmpty()) {
            val high = item.thumbnails.filter {
                it.estimatedResolutionLevel == Image.ResolutionLevel.HIGH
            }
            val best = when {
                high.isNotEmpty() -> high.maxByOrNull { it.width * it.height }
                item.thumbnails.all { it.width < 480 } -> null
                else -> item.thumbnails.maxByOrNull { it.width * it.height }
            }
            if (best != null) return best.url
        }
        val raw = item.url ?: return null
        val videoId = when {
            raw.contains("/watch?v=") -> raw.substringAfter("v=").substringBefore("&").substringBefore("?")
            raw.contains("/shorts/") -> raw.substringAfter("/shorts/").substringBefore("?").substringBefore("&")
            raw.startsWith("/") && raw.length == 12 -> raw.substring(1)
            else -> raw.substringAfterLast("/").substringBefore("?").substringBefore("&")
        }
        return if (videoId.length == 11) "https://i.ytimg.com/vi/$videoId/maxresdefault.jpg" else null
    }

    private fun bestImage(images: List<Image>): String? {
        return images.maxWithOrNull(
            compareBy<Image> {
                when (it.estimatedResolutionLevel) {
                    Image.ResolutionLevel.HIGH -> 3
                    Image.ResolutionLevel.MEDIUM -> 2
                    Image.ResolutionLevel.LOW -> 1
                    else -> 0
                }
            }.thenByDescending { it.width * it.height },
        )?.url
    }

    private fun serializePage(page: Page?): String? {
        if (page == null) return null
        return gson.toJson(
            mapOf(
                "url" to page.url,
                "id" to page.id,
                "ids" to page.ids,
                "body" to page.body?.let { Base64.getEncoder().encodeToString(it) },
            ),
        )
    }

    private fun deserializePage(json: String): Page {
        val pageMap = gson.fromJson(json, Map::class.java)
        val url = pageMap["url"] as? String
        val id = pageMap["id"] as? String
        @Suppress("UNCHECKED_CAST")
        val ids = (pageMap["ids"] as? List<*>)?.map { it.toString() }
        val body = (pageMap["body"] as? String)?.let { Base64.getDecoder().decode(it) }
        return when {
            ids != null && body != null -> Page(url, id, ids, null, body)
            ids != null -> Page(ids)
            body != null -> Page(url, id, body)
            id != null -> Page(url, id)
            url != null -> Page(url)
            else -> throw ArgException("Invalid page data")
        }
    }

    private fun required(args: JsonObject, key: String): String {
        val value = optional(args, key)
        if (value.isNullOrBlank()) throw ArgException("$key is required")
        return value
    }

    private fun optional(args: JsonObject, key: String): String? {
        if (!args.has(key) || args.get(key).isJsonNull) return null
        return args.get(key).asString
    }

    private fun stringList(args: JsonObject, key: String): List<String> {
        if (!args.has(key) || args.get(key).isJsonNull) return emptyList()
        return args.getAsJsonArray(key).map { it.asString }
    }

    private fun reply(
        id: Any?,
        ok: Boolean,
        result: String? = null,
        code: String? = null,
        message: String? = null,
    ) {
        val payload = linkedMapOf<String, Any?>(
            "id" to unwrapId(id),
            "ok" to ok,
        )
        if (ok) {
            payload["result"] = result
        } else {
            payload["code"] = code
            payload["message"] = message
        }
        println(gson.toJson(payload))
        System.out.flush()
    }

    private fun unwrapId(id: Any?): Any? {
        val element = id as? com.google.gson.JsonElement ?: return id
        if (element.isJsonNull) return null
        if (element.isJsonPrimitive && element.asJsonPrimitive.isNumber) {
            return element.asLong
        }
        return if (element.isJsonPrimitive) element.asString else element.toString()
    }

    private class ArgException(message: String) : IllegalArgumentException(message)

    private class CachedStreamInfo(val streamInfo: StreamInfo, val timestampMs: Long)
}

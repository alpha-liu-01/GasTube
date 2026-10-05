const selectedDefaultLanguage = 'default-language';
const selectedDefaultQuality = 'default-quality';
const selectedDefaultRegion = 'default-region';

/// Preferred video codec when a video offers both H.264 and VP9.
const defaultVideoCodecKey = 'default-video-codec';
const defaultVideoCodecH264 = 'h264';
const defaultVideoCodecVp9 = 'vp9';

String normalizeDefaultVideoCodec(String? value) {
  return value == defaultVideoCodecVp9
      ? defaultVideoCodecVp9
      : defaultVideoCodecH264;
}

const selectedTheme = 'theme';
const historyVisibility = 'history-visibility';
const dislikeVisibility = 'dislike-visibility';
const hlsPlayer = 'hls-player';
const commentsVisibility = 'comments-visibility';
const relatedVideoVisibility = 'related-video-visibility';
const instanceApiUrl = 'instance-api';
const youtubeService = 'yt-service';
const pipDisabled = 'pip-disabled';

// Search filters
const searchFilterKey = 'search-filter';

// Video fit mode
const videoFitModeKey = 'video-fit-mode';

// Skip interval (in seconds)
const skipIntervalKey = 'skip-interval';

// SponsorBlock settings
const sponsorBlockEnabledKey = 'sponsorblock-enabled';
const sponsorBlockCategoriesKey = 'sponsorblock-categories';

// Open links in browser
const openLinksInBrowserKey = 'open-links-browser';

// Home feed mode (feedOrTrending, feedOnly, trendingOnly)
const homeFeedModeKey = 'home-feed-mode';

// Audio focus / pause on interruption
const audioFocusEnabledKey = 'audio-focus-enabled';

// Subtitle size (font size in pixels)
const subtitleSizeKey = 'subtitle-size';

// Profiles
const currentProfileKey = 'current-profile';
const profilesListKey = 'profiles-list';

// Sync
const syncEnabledKey = 'sync-enabled';
const lastSyncedKey = 'last-synced';

// Search history privacy
const searchHistoryEnabledKey = 'search-history-enabled';
const searchHistoryVisibilityKey = 'search-history-visibility';

// Auto PiP (enter PiP when pressing home button while video is playing)
const autoPipEnabledKey = 'auto-pip-enabled';

// Desktop window fullscreen. Hides the title bar on Linux phones (Phosh).
const windowFullscreenKey = 'window-fullscreen';

// Player fullscreen follows the video aspect. Default off, per install.
const fullscreenAspectRotateKey = 'fullscreen-aspect-rotate';

// New-upload notifications for subscribed channels
const notifyNewVideosKey = 'notify-new-videos';
const notifyLastCheckKey = 'notify-last-check';
const notifySeenVideosKey = 'notify-seen-videos';

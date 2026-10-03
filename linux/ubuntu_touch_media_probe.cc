#include <dlfcn.h>

#include <cstdio>
#include <sys/types.h>

// The phone already has libhybris libmedia.so.1. This probe asks which
// decoder serves video/avc. Playback feeds H.264 packets through h264_hybris.
extern "C" void gastube_ut_probe_media_codec() {
  void* library = dlopen("libmedia.so.1", RTLD_NOW | RTLD_GLOBAL);
  if (library == nullptr) {
    std::fprintf(stderr, "gastube: mediacodec dlopen failed: %s\n", dlerror());
    std::fprintf(stderr, "gastube: decode=software-h264\n");
    return;
  }

  using InitFn = void (*)();
  using FindFn = ssize_t (*)(const char*, bool, size_t);
  using NameFn = const char* (*)(size_t);
  using InfoFn = void (*)(size_t);
  auto init = reinterpret_cast<InitFn>(dlsym(library, "hybris_media_initialize"));
  auto find = reinterpret_cast<FindFn>(
      dlsym(library, "media_codec_list_find_codec_by_type"));
  auto name = reinterpret_cast<NameFn>(
      dlsym(library, "media_codec_list_get_codec_name"));
  auto info = reinterpret_cast<InfoFn>(
      dlsym(library, "media_codec_list_get_codec_info_at_id"));
  if (init == nullptr || find == nullptr || name == nullptr) {
    std::fprintf(stderr, "gastube: mediacodec symbols missing\n");
    std::fprintf(stderr, "gastube: decode=software-h264\n");
    return;
  }

  init();
  const ssize_t index = find("video/avc", false, 0);
  if (index < 0) {
    std::fprintf(stderr, "gastube: mediacodec video/avc index=%zd\n", index);
    std::fprintf(stderr, "gastube: decode=software-h264\n");
    return;
  }
  if (info != nullptr) {
    info(static_cast<size_t>(index));
  }
  const char* codec = name(static_cast<size_t>(index));
  std::fprintf(stderr, "gastube: mediacodec video/avc name=%s\n",
               codec != nullptr ? codec : "(null)");
}

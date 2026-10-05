#include <dlfcn.h>

#include <cstdio>
#include <sys/types.h>

// The phone already has libhybris libmedia.so.1. This probe asks which
// decoder serves video/avc and video/x-vnd.on2.vp9. It does not feed packets.
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
  const ssize_t avc = find("video/avc", false, 0);
  if (avc < 0) {
    std::fprintf(stderr, "gastube: mediacodec video/avc index=%zd\n", avc);
    std::fprintf(stderr, "gastube: decode=software-h264\n");
  } else {
    if (info != nullptr) {
      info(static_cast<size_t>(avc));
    }
    const char* codec = name(static_cast<size_t>(avc));
    std::fprintf(stderr, "gastube: mediacodec video/avc name=%s\n",
                 codec != nullptr ? codec : "(null)");
  }

  const char* vp9_mimes[] = {"video/x-vnd.on2.vp9", "video/vp9"};
  bool vp9_named = false;
  for (const char* mime : vp9_mimes) {
    size_t start = 0;
    bool mime_named = false;
    for (;;) {
      const ssize_t index = find(mime, false, start);
      if (index < 0 || static_cast<size_t>(index) < start) {
        if (!mime_named) {
          std::fprintf(stderr, "gastube: mediacodec %s index=%zd\n", mime, index);
        }
        break;
      }
      if (info != nullptr) {
        info(static_cast<size_t>(index));
      }
      const char* codec = name(static_cast<size_t>(index));
      std::fprintf(stderr, "gastube: mediacodec %s name=%s\n", mime,
                   codec != nullptr ? codec : "(null)");
      mime_named = codec != nullptr && codec[0] != '\0';
      vp9_named = vp9_named || mime_named;
      start = static_cast<size_t>(index) + 1;
    }
    if (vp9_named) {
      break;
    }
  }
  if (!vp9_named) {
    std::fprintf(stderr, "gastube: vp9-hw=absent\n");
  }
}

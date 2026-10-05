#include "pulse_unplug.h"

#include "pulse_route.h"

namespace {

FlMethodChannel* g_channel = nullptr;

gboolean emit_unplug(gpointer) {
  if (g_channel != nullptr) {
    fl_method_channel_invoke_method(g_channel, "unplug", nullptr, nullptr,
                                    nullptr, nullptr);
  }
  return G_SOURCE_REMOVE;
}

void queue_unplug() { g_idle_add(emit_unplug, nullptr); }

}  // namespace

void gastube_pulse_unplug_attach(FlView* view) {
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_channel = fl_method_channel_new(messenger, "lol.alphaliu01.gastube/pulse",
                                    FL_METHOD_CODEC(codec));
  gastube_pulse_route_watch(queue_unplug);
}

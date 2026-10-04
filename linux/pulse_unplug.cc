#include "pulse_unplug.h"

#include <pulse/pulseaudio.h>

#include <cstring>
#include <map>

namespace {

FlMethodChannel* g_channel = nullptr;
pa_threaded_mainloop* g_loop = nullptr;
pa_context* g_context = nullptr;
std::map<uint32_t, bool> g_card_wired;
bool g_baseline = false;

bool any_wired() {
  for (const auto& entry : g_card_wired) {
    if (entry.second) return true;
  }
  return false;
}

bool port_is_wired_output(const pa_card_port_info* port) {
  if (port == nullptr || port->name == nullptr) return false;
  if (port->available != PA_PORT_AVAILABLE_YES) return false;
  return std::strcmp(port->name, "output-wired_headphone") == 0 ||
         std::strcmp(port->name, "output-wired_headset") == 0;
}

bool card_has_wired_output(const pa_card_info* info) {
  if (info == nullptr || info->ports == nullptr) return false;
  for (uint32_t i = 0; i < info->n_ports; i++) {
    if (port_is_wired_output(info->ports[i])) return true;
  }
  return false;
}

gboolean emit_unplug(gpointer) {
  if (g_channel != nullptr) {
    fl_method_channel_invoke_method(g_channel, "unplug", nullptr, nullptr,
                                    nullptr, nullptr);
  }
  return G_SOURCE_REMOVE;
}

void note_card(const pa_card_info* info) {
  const bool was = any_wired();
  g_card_wired[info->index] = card_has_wired_output(info);
  const bool now = any_wired();
  if (!g_baseline || !was || now) return;
  g_message("gastube: pulse unplug");
  g_idle_add(emit_unplug, nullptr);
}

void on_card(pa_context*, const pa_card_info* info, int eol, void*) {
  if (eol != 0) {
    g_baseline = true;
    return;
  }
  if (info != nullptr) note_card(info);
}

void on_subscribe(pa_context* context, pa_subscription_event_type_t type,
                  uint32_t index, void*) {
  const auto facility = type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK;
  const auto kind = type & PA_SUBSCRIPTION_EVENT_TYPE_MASK;
  if (facility != PA_SUBSCRIPTION_EVENT_CARD ||
      kind != PA_SUBSCRIPTION_EVENT_CHANGE) {
    return;
  }
  pa_operation* operation =
      pa_context_get_card_info_by_index(context, index, on_card, nullptr);
  if (operation != nullptr) pa_operation_unref(operation);
}

void on_state(pa_context*, void* userdata) {
  auto* loop = static_cast<pa_threaded_mainloop*>(userdata);
  pa_threaded_mainloop_signal(loop, 0);
}

}  // namespace

void gastube_pulse_unplug_attach(FlView* view) {
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_channel = fl_method_channel_new(messenger, "lol.alphaliu01.gastube/pulse",
                                    FL_METHOD_CODEC(codec));

  g_loop = pa_threaded_mainloop_new();
  if (g_loop == nullptr) {
    g_message("gastube: pulse unplug failed error=mainloop");
    return;
  }
  pa_mainloop_api* api = pa_threaded_mainloop_get_api(g_loop);
  g_context = pa_context_new(api, "gastube");
  if (g_context == nullptr) {
    g_message("gastube: pulse unplug failed error=context");
    return;
  }
  pa_context_set_state_callback(g_context, on_state, g_loop);
  if (pa_context_connect(g_context, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
    g_message("gastube: pulse unplug failed error=connect");
    return;
  }
  if (pa_threaded_mainloop_start(g_loop) < 0) {
    g_message("gastube: pulse unplug failed error=start");
    return;
  }
  pa_threaded_mainloop_lock(g_loop);
  while (true) {
    const pa_context_state_t state = pa_context_get_state(g_context);
    if (state == PA_CONTEXT_READY || state == PA_CONTEXT_FAILED ||
        state == PA_CONTEXT_TERMINATED) {
      break;
    }
    pa_threaded_mainloop_wait(g_loop);
  }
  if (pa_context_get_state(g_context) != PA_CONTEXT_READY) {
    pa_threaded_mainloop_unlock(g_loop);
    g_message("gastube: pulse unplug failed error=ready");
    return;
  }
  pa_context_set_subscribe_callback(g_context, on_subscribe, nullptr);
  pa_operation* subscribed = pa_context_subscribe(
      g_context, PA_SUBSCRIPTION_MASK_CARD, nullptr, nullptr);
  if (subscribed != nullptr) pa_operation_unref(subscribed);
  pa_operation* listed =
      pa_context_get_card_info_list(g_context, on_card, nullptr);
  if (listed != nullptr) pa_operation_unref(listed);
  pa_threaded_mainloop_unlock(g_loop);
  g_message("gastube: pulse ports watching");
}

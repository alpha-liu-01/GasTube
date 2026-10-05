#include "pulse_route.h"

#include <glib.h>
#include <pulse/pulseaudio.h>

#include <cstring>
#include <map>
#include <string>

namespace {

struct CardState {
  bool external = false;
  bool wired = false;
  std::string name;
};

struct SinkState {
  bool usb = false;
  std::string port;
};

pa_threaded_mainloop* g_loop = nullptr;
pa_context* g_context = nullptr;
std::map<uint32_t, CardState> g_cards;
std::map<uint32_t, SinkState> g_sinks;
bool g_card_baseline = false;
bool g_sink_baseline = false;
void (*g_on_unplug)() = nullptr;

bool text_has_usb(const char* text) {
  if (text == nullptr) return false;
  for (const char* p = text; p[0] != '\0' && p[1] != '\0' && p[2] != '\0';
       ++p) {
    if ((p[0] == 'u' || p[0] == 'U') && (p[1] == 's' || p[1] == 'S') &&
        (p[2] == 'b' || p[2] == 'B')) {
      return true;
    }
  }
  return false;
}

bool property_is_usb(pa_proplist* props) {
  if (props == nullptr) return false;
  const char* bus = pa_proplist_gets(props, "device.bus");
  if (bus != nullptr && std::strcmp(bus, "usb") == 0) return true;
  return text_has_usb(pa_proplist_gets(props, "device.description"));
}

void fire(const char* reason, const char* name) {
  g_message("gastube: pulse unplug reason=%s name=%s", reason,
            name == nullptr ? "" : name);
  if (g_on_unplug != nullptr) g_on_unplug();
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

bool any_wired() {
  for (const auto& entry : g_cards) {
    if (entry.second.wired) return true;
  }
  return false;
}

void note_card(const pa_card_info* info) {
  if (info == nullptr) return;
  const bool was_wired = any_wired();
  const char* name = info->name == nullptr ? "" : info->name;
  const bool primary = std::strcmp(name, "droid_card.primary") == 0;
  CardState state;
  state.name = name;
  state.wired = card_has_wired_output(info);
  const auto existing = g_cards.find(info->index);
  if (existing != g_cards.end() && existing->second.external) {
    state.external = true;
  } else if (!primary &&
             (property_is_usb(info->proplist) || text_has_usb(name))) {
    state.external = true;
  }
  g_cards[info->index] = state;
  if (!g_card_baseline || !was_wired || any_wired()) return;
  fire("wired", name);
}

void note_sink(const pa_sink_info* info) {
  if (info == nullptr) return;
  const char* name = info->name == nullptr ? "" : info->name;
  const char* port = nullptr;
  if (info->active_port != nullptr) port = info->active_port->name;
  SinkState state;
  state.usb = property_is_usb(info->proplist) || text_has_usb(name);
  if (port != nullptr) state.port = port;
  const auto existing = g_sinks.find(info->index);
  const std::string previous =
      existing == g_sinks.end() ? std::string() : existing->second.port;
  if (existing != g_sinks.end() && existing->second.usb) state.usb = true;
  g_sinks[info->index] = state;
  if (!g_sink_baseline) return;
  if (previous == "output-usb_device" && state.port != "output-usb_device") {
    fire("usb-port", name);
  }
}

void on_card(pa_context*, const pa_card_info* info, int eol, void* userdata) {
  if (eol != 0) {
    if (userdata != nullptr) g_card_baseline = true;
    return;
  }
  note_card(info);
}

void on_sink(pa_context*, const pa_sink_info* info, int eol, void* userdata) {
  if (eol != 0) {
    if (userdata != nullptr) g_sink_baseline = true;
    return;
  }
  note_sink(info);
}

void drop_card(uint32_t index) {
  const auto existing = g_cards.find(index);
  if (existing == g_cards.end()) return;
  const CardState state = existing->second;
  const bool was_wired = any_wired();
  g_cards.erase(existing);
  if (!g_card_baseline) return;
  if (state.external) {
    fire("usb-card", state.name.c_str());
    return;
  }
  if (was_wired && !any_wired()) fire("wired", state.name.c_str());
}

void drop_sink(uint32_t index) {
  const auto existing = g_sinks.find(index);
  if (existing == g_sinks.end()) return;
  const SinkState state = existing->second;
  g_sinks.erase(existing);
  if (!g_sink_baseline || !state.usb) return;
  fire("usb-sink", state.port.c_str());
}

void on_subscribe(pa_context* context, pa_subscription_event_type_t type,
                  uint32_t index, void*) {
  const auto facility = type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK;
  const auto kind = type & PA_SUBSCRIPTION_EVENT_TYPE_MASK;
  if (facility == PA_SUBSCRIPTION_EVENT_CARD) {
    if (kind == PA_SUBSCRIPTION_EVENT_REMOVE) {
      drop_card(index);
      return;
    }
    if (kind != PA_SUBSCRIPTION_EVENT_NEW &&
        kind != PA_SUBSCRIPTION_EVENT_CHANGE) {
      return;
    }
    pa_operation* operation =
        pa_context_get_card_info_by_index(context, index, on_card, nullptr);
    if (operation != nullptr) pa_operation_unref(operation);
    return;
  }
  if (facility != PA_SUBSCRIPTION_EVENT_SINK) return;
  if (kind == PA_SUBSCRIPTION_EVENT_REMOVE) {
    drop_sink(index);
    return;
  }
  if (kind != PA_SUBSCRIPTION_EVENT_NEW &&
      kind != PA_SUBSCRIPTION_EVENT_CHANGE) {
    return;
  }
  pa_operation* operation =
      pa_context_get_sink_info_by_index(context, index, on_sink, nullptr);
  if (operation != nullptr) pa_operation_unref(operation);
}

void on_state(pa_context*, void* userdata) {
  auto* loop = static_cast<pa_threaded_mainloop*>(userdata);
  pa_threaded_mainloop_signal(loop, 0);
}

}  // namespace

void gastube_pulse_route_watch(void (*on_unplug)()) {
  g_on_unplug = on_unplug;
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
      g_context,
      static_cast<pa_subscription_mask_t>(PA_SUBSCRIPTION_MASK_CARD |
                                          PA_SUBSCRIPTION_MASK_SINK),
      nullptr, nullptr);
  if (subscribed != nullptr) pa_operation_unref(subscribed);
  pa_operation* cards =
      pa_context_get_card_info_list(g_context, on_card, g_context);
  if (cards != nullptr) pa_operation_unref(cards);
  pa_operation* sinks =
      pa_context_get_sink_info_list(g_context, on_sink, g_context);
  if (sinks != nullptr) pa_operation_unref(sinks);
  pa_threaded_mainloop_unlock(g_loop);
  g_message("gastube: pulse ports watching");
}

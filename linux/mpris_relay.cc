// Owns the GasTube MPRIS name while Lomiri has stopped the click process.
// Audio stays on the media-hub session this process is given. This binary
// only forwards pause and resume to that session.

#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <gio/gio.h>
#include <glib-unix.h>

namespace {

constexpr int kRequestPrimaryOwner = 1;
constexpr int kRequestAlreadyOwner = 4;

struct Relay {
  GDBusConnection* bus = nullptr;
  GDBusConnection* hub = nullptr;
  GMainLoop* loop = nullptr;
  guint tick = 0;
  bool quitting = false;
  bool have_name = false;
  bool paused = false;
  int parent_pid = 0;
  int64_t length_us = 0;
  char* session_path = nullptr;
  char* title = nullptr;
  char* artist = nullptr;
  char* art_url = nullptr;
  char* desktop_entry = nullptr;
  char* ready_path = nullptr;
};

Relay g_relay;

void note(const char* text) {
  fprintf(stderr, "gastube-mpris-relay: %s\n", text);
}

void write_ready(const char* text) {
  if (g_relay.ready_path == nullptr) return;
  g_file_set_contents(g_relay.ready_path, text, -1, nullptr);
}

const char* playback_status(const Relay* relay) {
  return relay->paused ? "Paused" : "Playing";
}

GVariant* metadata(const Relay* relay) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(
      &builder, "{sv}", "mpris:trackid",
      g_variant_new_object_path("/org/mpris/MediaPlayer2/track/0"));
  g_variant_builder_add(&builder, "{sv}", "xesam:title",
                        g_variant_new_string(relay->title));
  const char* artist = relay->artist;
  g_variant_builder_add(&builder, "{sv}", "xesam:artist",
                        g_variant_new_strv(&artist, 1));
  if (relay->art_url != nullptr && relay->art_url[0] != '\0') {
    g_variant_builder_add(&builder, "{sv}", "mpris:artUrl",
                          g_variant_new_string(relay->art_url));
  }
  if (relay->length_us > 0) {
    g_variant_builder_add(&builder, "{sv}", "mpris:length",
                          g_variant_new_int64(relay->length_us));
  }
  return g_variant_builder_end(&builder);
}

GVariant* player_properties(const Relay* relay) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&builder, "{sv}", "PlaybackStatus",
                        g_variant_new_string(playback_status(relay)));
  g_variant_builder_add(&builder, "{sv}", "Metadata", metadata(relay));
  g_variant_builder_add(&builder, "{sv}", "LoopStatus",
                        g_variant_new_string("None"));
  g_variant_builder_add(&builder, "{sv}", "Rate", g_variant_new_double(1));
  g_variant_builder_add(&builder, "{sv}", "Shuffle",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "Volume", g_variant_new_double(1));
  g_variant_builder_add(&builder, "{sv}", "Position", g_variant_new_int64(0));
  g_variant_builder_add(&builder, "{sv}", "MinimumRate",
                        g_variant_new_double(1));
  g_variant_builder_add(&builder, "{sv}", "MaximumRate",
                        g_variant_new_double(1));
  g_variant_builder_add(&builder, "{sv}", "CanGoNext",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "CanGoPrevious",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "CanPlay",
                        g_variant_new_boolean(TRUE));
  g_variant_builder_add(&builder, "{sv}", "CanPause",
                        g_variant_new_boolean(TRUE));
  g_variant_builder_add(&builder, "{sv}", "CanSeek",
                        g_variant_new_boolean(TRUE));
  g_variant_builder_add(&builder, "{sv}", "CanControl",
                        g_variant_new_boolean(TRUE));
  return g_variant_builder_end(&builder);
}

GVariant* root_properties(const Relay* relay) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&builder, "{sv}", "CanQuit",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "CanRaise",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "HasTrackList",
                        g_variant_new_boolean(FALSE));
  g_variant_builder_add(&builder, "{sv}", "Identity",
                        g_variant_new_string("GasTube"));
  g_variant_builder_add(&builder, "{sv}", "DesktopEntry",
                        g_variant_new_string(relay->desktop_entry));
  const char* schemes[] = {"file"};
  g_variant_builder_add(&builder, "{sv}", "SupportedUriSchemes",
                        g_variant_new_strv(schemes, 1));
  const char* types[] = {"audio/mp4"};
  g_variant_builder_add(&builder, "{sv}", "SupportedMimeTypes",
                        g_variant_new_strv(types, 1));
  return g_variant_builder_end(&builder);
}

void emit_status(Relay* relay) {
  if (relay->bus == nullptr || !relay->have_name) return;
  GVariantBuilder changed;
  g_variant_builder_init(&changed, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&changed, "{sv}", "PlaybackStatus",
                        g_variant_new_string(playback_status(relay)));
  g_variant_builder_add(&changed, "{sv}", "Metadata", metadata(relay));
  GVariant* changed_value = g_variant_ref_sink(g_variant_builder_end(&changed));
  GVariant* invalidated = g_variant_ref_sink(
      g_variant_new_array(G_VARIANT_TYPE_STRING, nullptr, 0));
  GVariant* body =
      g_variant_new("(s@a{sv}@as)", "org.mpris.MediaPlayer2.Player",
                    changed_value, invalidated);
  g_dbus_connection_emit_signal(relay->bus, nullptr, "/org/mpris/MediaPlayer2",
                                "org.freedesktop.DBus.Properties",
                                "PropertiesChanged", body, nullptr);
}

bool hub_paused(Relay* relay, bool* paused) {
  if (relay->hub == nullptr || relay->session_path == nullptr) return false;
  GError* error = nullptr;
  GVariant* reply = g_dbus_connection_call_sync(
      relay->hub, "com.lomiri.MediaHub.Service", relay->session_path,
      "org.freedesktop.DBus.Properties", "Get",
      g_variant_new("(ss)", "org.mpris.MediaPlayer2.Player", "PlaybackStatus"),
      G_VARIANT_TYPE("(v)"), G_DBUS_CALL_FLAGS_NONE, 1000, nullptr, &error);
  if (reply == nullptr) {
    g_clear_error(&error);
    return false;
  }
  GVariant* inner = nullptr;
  g_variant_get(reply, "(v)", &inner);
  g_variant_unref(reply);
  if (inner == nullptr || !g_variant_is_of_type(inner, G_VARIANT_TYPE_STRING)) {
    if (inner != nullptr) g_variant_unref(inner);
    return false;
  }
  const char* status = g_variant_get_string(inner, nullptr);
  *paused = status == nullptr || strcmp(status, "Playing") != 0;
  g_variant_unref(inner);
  return true;
}

bool hub_call(Relay* relay, const char* method) {
  if (relay->hub == nullptr || relay->session_path == nullptr) return false;
  GError* error = nullptr;
  GVariant* reply = g_dbus_connection_call_sync(
      relay->hub, "com.lomiri.MediaHub.Service", relay->session_path,
      "org.mpris.MediaPlayer2.Player", method, nullptr, nullptr,
      G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, &error);
  if (reply == nullptr) {
    fprintf(stderr, "gastube-mpris-relay: %s %s\n", method,
            error == nullptr ? "failed" : error->message);
    g_clear_error(&error);
    return false;
  }
  g_variant_unref(reply);
  return true;
}

void set_paused(Relay* relay, bool paused) {
  if (!hub_call(relay, paused ? "Pause" : "Play")) return;
  relay->paused = paused;
  emit_status(relay);
  note(paused ? "paused" : "resumed");
}

void release_name(Relay* relay) {
  if (relay->bus == nullptr || !relay->have_name) return;
  g_dbus_connection_call_sync(
      relay->bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "ReleaseName",
      g_variant_new("(s)", "org.mpris.MediaPlayer2.gastube"), nullptr,
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr);
  relay->have_name = false;
}

extern "C" void on_method_call(GDBusConnection* /*connection*/,
                               const gchar* /*sender*/,
                               const gchar* /*object_path*/,
                               const gchar* interface_name,
                               const gchar* method_name, GVariant* parameters,
                               GDBusMethodInvocation* invocation,
                               gpointer /*user_data*/) {
  Relay* relay = &g_relay;
  if (strcmp(interface_name, "org.freedesktop.DBus.Properties") == 0) {
    if (strcmp(method_name, "Get") == 0) {
      const char* iface = nullptr;
      const char* name = nullptr;
      g_variant_get(parameters, "(&s&s)", &iface, &name);
      GVariant* all = g_variant_ref_sink(
          strcmp(iface, "org.mpris.MediaPlayer2") == 0 ? root_properties(relay)
                                                       : player_properties(relay));
      GVariant* value = g_variant_lookup_value(all, name, nullptr);
      g_variant_unref(all);
      if (value == nullptr) {
        g_dbus_method_invocation_return_error_literal(
            invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_PROPERTY, name);
        return;
      }
      g_dbus_method_invocation_return_value(invocation,
                                            g_variant_new("(v)", value));
      g_variant_unref(value);
      return;
    }
    if (strcmp(method_name, "GetAll") == 0) {
      const char* iface = nullptr;
      g_variant_get(parameters, "(&s)", &iface);
      GVariant* all = g_variant_ref_sink(
          strcmp(iface, "org.mpris.MediaPlayer2") == 0 ? root_properties(relay)
                                                       : player_properties(relay));
      g_dbus_method_invocation_return_value(invocation,
                                            g_variant_new("(@a{sv})", all));
      return;
    }
    g_dbus_method_invocation_return_error_literal(
        invocation, G_DBUS_ERROR, G_DBUS_ERROR_PROPERTY_READ_ONLY, method_name);
    return;
  }
  if (strcmp(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
    if (strcmp(method_name, "Play") == 0) {
      set_paused(relay, false);
    } else if (strcmp(method_name, "Pause") == 0 ||
               strcmp(method_name, "Stop") == 0) {
      set_paused(relay, true);
    } else if (strcmp(method_name, "PlayPause") == 0) {
      bool paused = relay->paused;
      hub_paused(relay, &paused);
      set_paused(relay, !paused);
    } else if (strcmp(method_name, "Seek") != 0 &&
               strcmp(method_name, "SetPosition") != 0 &&
               strcmp(method_name, "Next") != 0 &&
               strcmp(method_name, "Previous") != 0 &&
               strcmp(method_name, "OpenUri") != 0) {
      g_dbus_method_invocation_return_error_literal(
          invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD, method_name);
      return;
    }
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

const GDBusInterfaceVTable kVtable = {on_method_call, nullptr, nullptr};

const char kXml[] =
    "<node>"
    "  <interface name='org.mpris.MediaPlayer2'>"
    "    <method name='Raise'/>"
    "    <method name='Quit'/>"
    "    <property name='CanQuit' type='b' access='read'/>"
    "    <property name='CanRaise' type='b' access='read'/>"
    "    <property name='HasTrackList' type='b' access='read'/>"
    "    <property name='Identity' type='s' access='read'/>"
    "    <property name='DesktopEntry' type='s' access='read'/>"
    "    <property name='SupportedUriSchemes' type='as' access='read'/>"
    "    <property name='SupportedMimeTypes' type='as' access='read'/>"
    "  </interface>"
    "  <interface name='org.mpris.MediaPlayer2.Player'>"
    "    <method name='Next'/>"
    "    <method name='Previous'/>"
    "    <method name='Pause'/>"
    "    <method name='PlayPause'/>"
    "    <method name='Stop'/>"
    "    <method name='Play'/>"
    "    <method name='Seek'><arg name='Offset' type='x' direction='in'/></method>"
    "    <method name='SetPosition'>"
    "      <arg name='TrackId' type='o' direction='in'/>"
    "      <arg name='Position' type='x' direction='in'/>"
    "    </method>"
    "    <method name='OpenUri'><arg name='Uri' type='s' direction='in'/></method>"
    "    <signal name='Seeked'><arg name='Position' type='x'/></signal>"
    "    <property name='PlaybackStatus' type='s' access='read'/>"
    "    <property name='LoopStatus' type='s' access='read'/>"
    "    <property name='Rate' type='d' access='read'/>"
    "    <property name='Shuffle' type='b' access='read'/>"
    "    <property name='Metadata' type='a{sv}' access='read'/>"
    "    <property name='Volume' type='d' access='read'/>"
    "    <property name='Position' type='x' access='read'/>"
    "    <property name='MinimumRate' type='d' access='read'/>"
    "    <property name='MaximumRate' type='d' access='read'/>"
    "    <property name='CanGoNext' type='b' access='read'/>"
    "    <property name='CanGoPrevious' type='b' access='read'/>"
    "    <property name='CanPlay' type='b' access='read'/>"
    "    <property name='CanPause' type='b' access='read'/>"
    "    <property name='CanSeek' type='b' access='read'/>"
    "    <property name='CanControl' type='b' access='read'/>"
    "  </interface>"
    "  <interface name='org.freedesktop.DBus.Properties'>"
    "    <method name='Get'>"
    "      <arg type='s' direction='in'/>"
    "      <arg type='s' direction='in'/>"
    "      <arg type='v' direction='out'/>"
    "    </method>"
    "    <method name='Set'>"
    "      <arg type='s' direction='in'/>"
    "      <arg type='s' direction='in'/>"
    "      <arg type='v' direction='in'/>"
    "    </method>"
    "    <method name='GetAll'>"
    "      <arg type='s' direction='in'/>"
    "      <arg type='a{sv}' direction='out'/>"
    "    </method>"
    "    <signal name='PropertiesChanged'>"
    "      <arg type='s'/>"
    "      <arg type='a{sv}'/>"
    "      <arg type='as'/>"
    "    </signal>"
    "  </interface>"
    "</node>";

bool register_objects(Relay* relay) {
  GError* error = nullptr;
  GDBusNodeInfo* info = g_dbus_node_info_new_for_xml(kXml, &error);
  if (info == nullptr) {
    fprintf(stderr, "gastube-mpris-relay: xml %s\n",
            error == nullptr ? "failed" : error->message);
    g_clear_error(&error);
    return false;
  }
  for (GDBusInterfaceInfo** iface = info->interfaces; *iface != nullptr;
       iface++) {
    g_dbus_connection_register_object(relay->bus, "/org/mpris/MediaPlayer2",
                                      *iface, &kVtable, nullptr, nullptr,
                                      &error);
    if (error != nullptr) {
      fprintf(stderr, "gastube-mpris-relay: register %s\n", error->message);
      g_clear_error(&error);
      g_dbus_node_info_unref(info);
      return false;
    }
  }
  g_dbus_node_info_unref(info);
  return true;
}

bool claim_name(Relay* relay) {
  if (relay->have_name || relay->bus == nullptr) return relay->have_name;
  GError* error = nullptr;
  GVariant* reply = g_dbus_connection_call_sync(
      relay->bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "RequestName",
      g_variant_new("(su)", "org.mpris.MediaPlayer2.gastube", 0),
      G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (reply == nullptr) {
    fprintf(stderr, "gastube-mpris-relay: request name %s\n",
            error == nullptr ? "failed" : error->message);
    g_clear_error(&error);
    return false;
  }
  guint32 result = 0;
  g_variant_get(reply, "(u)", &result);
  g_variant_unref(reply);
  if (result != kRequestPrimaryOwner && result != kRequestAlreadyOwner) {
    return false;
  }
  relay->have_name = true;
  note("name owned");
  emit_status(relay);
  write_ready("ready\n");
  return true;
}

extern "C" gboolean on_tick(gpointer /*data*/) {
  Relay* relay = &g_relay;
  if (relay->quitting) return G_SOURCE_REMOVE;
  if (relay->parent_pid > 0 && kill(relay->parent_pid, 0) != 0) {
    note("parent gone");
    relay->quitting = true;
    release_name(relay);
    g_main_loop_quit(relay->loop);
    return G_SOURCE_REMOVE;
  }
  claim_name(relay);
  static int polls = 0;
  if (relay->have_name && ++polls >= 10) {
    polls = 0;
    bool paused = relay->paused;
    if (hub_paused(relay, &paused) && paused != relay->paused) {
      relay->paused = paused;
      emit_status(relay);
    }
  }
  return G_SOURCE_CONTINUE;
}

extern "C" gboolean on_sigterm(gpointer /*data*/) {
  note("stop");
  g_relay.quitting = true;
  release_name(&g_relay);
  if (g_relay.loop != nullptr) g_main_loop_quit(g_relay.loop);
  return G_SOURCE_REMOVE;
}

}  // namespace

int main(int argc, char** argv) {
  GOptionEntry entries[] = {
      {"parent-pid", 0, 0, G_OPTION_ARG_INT, &g_relay.parent_pid, "App pid",
       "PID"},
      {"session-path", 0, 0, G_OPTION_ARG_STRING, &g_relay.session_path,
       "media-hub session", "PATH"},
      {"title", 0, 0, G_OPTION_ARG_STRING, &g_relay.title, "Title", "TEXT"},
      {"artist", 0, 0, G_OPTION_ARG_STRING, &g_relay.artist, "Artist", "TEXT"},
      {"art", 0, 0, G_OPTION_ARG_STRING, &g_relay.art_url, "Art", "URL"},
      {"desktop-entry", 0, 0, G_OPTION_ARG_STRING, &g_relay.desktop_entry,
       "Desktop", "ID"},
      {"length-us", 0, 0, G_OPTION_ARG_INT64, &g_relay.length_us, "Length",
       "US"},
      {nullptr, 0, 0, G_OPTION_ARG_NONE, nullptr, nullptr, nullptr},
  };
  GError* error = nullptr;
  GOptionContext* context = g_option_context_new("");
  g_option_context_add_main_entries(context, entries, nullptr);
  if (!g_option_context_parse(context, &argc, &argv, &error)) {
    fprintf(stderr, "gastube-mpris-relay: %s\n", error->message);
    g_clear_error(&error);
    g_option_context_free(context);
    return 1;
  }
  g_option_context_free(context);
  if (g_relay.session_path == nullptr || g_relay.title == nullptr ||
      g_relay.desktop_entry == nullptr) {
    note("missing arguments");
    return 1;
  }
  if (g_relay.artist == nullptr) g_relay.artist = g_strdup("");
  const char* runtime = g_get_user_runtime_dir();
  g_relay.ready_path =
      g_build_filename(runtime, "gastube-mpris-relay.ready", nullptr);
  GError* bus_error = nullptr;
  g_relay.bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &bus_error);
  g_relay.hub = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (g_relay.bus == nullptr || g_relay.hub == nullptr) {
    const char* message = bus_error != nullptr
                              ? bus_error->message
                              : (error == nullptr ? "failed" : error->message);
    fprintf(stderr, "gastube-mpris-relay: bus %s\n", message);
    g_clear_error(&bus_error);
    g_clear_error(&error);
    write_ready("failed\n");
    return 1;
  }
  if (!register_objects(&g_relay)) {
    write_ready("failed\n");
    return 1;
  }
  g_relay.loop = g_main_loop_new(nullptr, FALSE);
  g_unix_signal_add(SIGTERM, on_sigterm, nullptr);
  g_unix_signal_add(SIGINT, on_sigterm, nullptr);
  g_relay.tick = g_timeout_add(100, on_tick, nullptr);
  claim_name(&g_relay);
  g_main_loop_run(g_relay.loop);
  if (g_relay.tick != 0) g_source_remove(g_relay.tick);
  release_name(&g_relay);
  if (g_relay.ready_path != nullptr) unlink(g_relay.ready_path);
  g_free(g_relay.ready_path);
  return 0;
}

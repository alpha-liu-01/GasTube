#include <flutter_linux/flutter_linux.h>

#include <gdk/gdk.h>
#include <gdk/gdkwayland.h>
#include <glib-unix.h>
#include <gtk/gtk.h>

#include <sys/socket.h>
#include <sys/un.h>

#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <execinfo.h>
#include <limits.h>
#include <signal.h>
#include <string>
#include <unistd.h>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

void gastube_ut_install_present_hook(GtkWidget* view);
void gastube_ut_set_present_allowed(bool allowed);

void on_fatal_signal(int sig) {
  const char* name = "signal";
  if (sig == SIGSEGV) name = "SIGSEGV";
  if (sig == SIGBUS) name = "SIGBUS";
  if (sig == SIGABRT) name = "SIGABRT";
  int length = 0;
  while (name[length] != '\0' && length < 16) length++;
  write(STDERR_FILENO, "gastube: fatal ", 15);
  write(STDERR_FILENO, name, length);
  write(STDERR_FILENO, "\n", 1);
  void* frames[48];
  int count = backtrace(frames, 48);
  backtrace_symbols_fd(frames, count, STDERR_FILENO);
  signal(sig, SIG_DFL);
  raise(sig);
}

void install_fatal_signals() {
  signal(SIGSEGV, on_fatal_signal);
  signal(SIGBUS, on_fatal_signal);
  signal(SIGABRT, on_fatal_signal);
}

namespace {

gchar* g_media_hub_uuid = nullptr;

// Swiping the app away destroys this window and returns from gtk_main before
// Dart can reach the media-hub session. Locking and switching apps leave the
// window in place, so this only runs when the process is actually going away.
void destroy_media_hub_session() {
  if (g_media_hub_uuid == nullptr) {
    g_message("gastube: mediahub window-destroy uuid=");
    return;
  }
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) {
    g_message("gastube: mediahub window-destroy bus failed %s",
              error != nullptr ? error->message : "unknown");
    g_free(g_media_hub_uuid);
    g_media_hub_uuid = nullptr;
    return;
  }
  g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
      bus, "com.lomiri.MediaHub.Service", "/com/lomiri/MediaHub/Service",
      "com.lomiri.MediaHub.Service", "DestroySession",
      g_variant_new("(s)", g_media_hub_uuid), nullptr, G_DBUS_CALL_FLAGS_NONE,
      500, nullptr, &error);
  g_message("gastube: mediahub window-destroy uuid=%s ok=%d", g_media_hub_uuid,
            reply != nullptr ? 1 : 0);
  if (error != nullptr) {
    g_message("gastube: mediahub window-destroy error=%s", error->message);
  }
  g_free(g_media_hub_uuid);
  g_media_hub_uuid = nullptr;
}

void on_destroy(GtkWidget*, gpointer) {
  g_message("gastube: mediahub window-destroy begin");
  destroy_media_hub_session();
  gtk_main_quit();
}

gboolean on_shutdown_signal(gpointer) {
  g_message("gastube: mediahub signal");
  destroy_media_hub_session();
  gtk_main_quit();
  return G_SOURCE_REMOVE;
}

void log_scale_environment() {
  const char* names[] = {"GDK_SCALE", "GDK_DPI_SCALE", "GRID_UNIT_PX",
                         "QT_SCALE_FACTOR", nullptr};
  for (int i = 0; names[i] != nullptr; i++) {
    const char* value = g_getenv(names[i]);
    g_message("env %s=%s", names[i], value != nullptr ? value : "(unset)");
  }
}

// UITK treats 8 device pixels as one grid unit at scale 1. GTK and the
// Flutter Linux embedder only accept an integer scale factor.
int scale_from_grid_unit(const char* grid) {
  if (grid == nullptr || grid[0] == '\0') return 0;
  char* end = nullptr;
  double gu = g_ascii_strtod(grid, &end);
  if (end == grid || gu < 8.0) return 0;
  int scale = static_cast<int>(std::lround(gu / 8.0));
  if (scale < 1) scale = 1;
  if (scale > 4) scale = 4;
  return scale;
}

int scale_from_monitor_mm(GdkMonitor* monitor) {
  int width_mm = gdk_monitor_get_width_mm(monitor);
  GdkRectangle geom;
  gdk_monitor_get_geometry(monitor, &geom);
  if (width_mm <= 0 || geom.width <= 0) return 0;
  double inches = width_mm / 25.4;
  double dpi = geom.width / inches;
  int scale = static_cast<int>(std::lround(dpi / 160.0));
  if (scale < 1) scale = 1;
  if (scale > 4) scale = 4;
  return scale;
}

int flutter_scale() {
  const char* grid = g_getenv("GRID_UNIT_PX");
  int scale = scale_from_grid_unit(grid);
  if (scale > 1) {
    std::fprintf(stderr,
                 "gastube: flutter scale %d from GRID_UNIT_PX=%s\n", scale,
                 grid);
    return scale;
  }
  return 0;
}

// The 6T exposes the panel and a larger virtual output. The panel is the
// smaller one. Geometry is in GTK logical pixels.
GdkMonitor* choose_panel(GdkDisplay* display) {
  int count = gdk_display_get_n_monitors(display);
  GdkMonitor* best = nullptr;
  int best_area = 0;
  for (int i = 0; i < count; i++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    GdkRectangle geom;
    gdk_monitor_get_geometry(monitor, &geom);
    int area = geom.width * geom.height;
    g_message(
        "monitor %d model=%s geometry=%dx%d+%d+%d scale=%d size_mm=%dx%d", i,
        gdk_monitor_get_model(monitor), geom.width, geom.height, geom.x,
        geom.y, gdk_monitor_get_scale_factor(monitor),
        gdk_monitor_get_width_mm(monitor), gdk_monitor_get_height_mm(monitor));
    if (area <= 0) continue;
    if (best == nullptr || area < best_area) {
      best = monitor;
      best_area = area;
    }
  }
  return best;
}

// Fullscreen tells Lomiri to hide the indicator panel. That is only for video.
// Maximized fills the stage underneath the panel.
void use_application_stage(GtkWindow* window) {
  gtk_window_set_decorated(window, FALSE);
  gtk_window_unfullscreen(window);
  gtk_window_maximize(window);
}

gboolean on_configure(GtkWidget*, GdkEventConfigure* event, gpointer) {
  static int last_width = 0;
  static int last_height = 0;
  if (event->width == last_width && event->height == last_height) return FALSE;
  last_width = event->width;
  last_height = event->height;
  g_message("configure %dx%d+%d+%d", event->width, event->height, event->x,
            event->y);
  return FALSE;
}

gboolean on_window_state(GtkWidget*, GdkEventWindowState* event, gpointer) {
  g_message("window state new=0x%x changed=0x%x", event->new_window_state,
            event->changed_mask);
  bool focused = (event->new_window_state & GDK_WINDOW_STATE_FOCUSED) != 0;
  gastube_ut_set_present_allowed(focused);
  return FALSE;
}

// Lomiri sets GTK_IM_MODULE=Maliit. The 6T image has no im-maliit.so, so GTK
// would look up a module that is not there. Drop the session value before
// gtk_init; choose_input_method() puts a real module in place afterwards.
void clear_session_im_module() {
  const char* value = g_getenv("GTK_IM_MODULE");
  g_message("GTK_IM_MODULE from session=%s",
            value != nullptr ? value : "(unset)");
  if (value != nullptr) {
    g_unsetenv("GTK_IM_MODULE");
  }
}

bool wayland_registry_has(GdkDisplay* display, const char* name) {
  if (display == nullptr || !GDK_IS_WAYLAND_DISPLAY(display)) return false;
  return gdk_wayland_display_query_registry(display, name);
}

// Mir on this image does not advertise a text-input global, so im-wayland.so
// has nothing to bind. The Click ships im-maliit.so and talks to maliit-server
// over the D-Bus socket the default Click policy already allows.
bool use_bundled_maliit() {
  char exe[PATH_MAX];
  ssize_t length = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
  if (length < 0) {
    g_warning("readlink /proc/self/exe failed");
    return false;
  }
  exe[length] = '\0';
  g_autofree char* dir = g_path_get_dirname(exe);
  g_autofree char* so_path = g_build_filename(dir, "lib", "im-maliit.so", nullptr);
  if (!g_file_test(so_path, G_FILE_TEST_IS_REGULAR)) {
    g_warning("im-maliit.so missing at %s", so_path);
    return false;
  }

  g_autofree char* cache_dir =
      g_build_filename(g_get_user_cache_dir(), "gastube.alphaliu01", nullptr);
  if (g_mkdir_with_parents(cache_dir, 0700) != 0) {
    g_warning("cannot create %s", cache_dir);
    return false;
  }
  g_autofree char* cache_path =
      g_build_filename(cache_dir, "immodules.cache", nullptr);
  g_autofree char* body = g_strdup_printf(
      "# GTK+ Input Method Modules file\n"
      "\"%s\"\n"
      "\"maliit\" \"Maliit\" \"gtk30\" \"\" \"\"\n",
      so_path);
  g_autoptr(GError) error = nullptr;
  if (!g_file_set_contents(cache_path, body, -1, &error)) {
    g_warning("cannot write %s: %s", cache_path,
              error != nullptr ? error->message : "unknown");
    return false;
  }

  g_setenv("GTK_IM_MODULE_FILE", cache_path, TRUE);
  g_setenv("GTK_IM_MODULE", "maliit", TRUE);
  g_message("GTK_IM_MODULE=maliit so=%s cache=%s", so_path, cache_path);
  return true;
}

void choose_input_method() {
  GdkDisplay* display = gdk_display_get_default();
  bool text_input_v3 =
      wayland_registry_has(display, "zwp_text_input_manager_v3");
  bool gtk_text_input =
      wayland_registry_has(display, "gtk_text_input_manager");
  g_message("wayland text-input v3=%d gtk_text_input_manager=%d",
            text_input_v3, gtk_text_input);
  if (text_input_v3) {
    g_message("Wayland text-input v3 is present; GTK selects im-wayland");
    return;
  }
  if (gtk_text_input) {
    g_setenv("GTK_IM_MODULE", "waylandgtk", TRUE);
    g_message("GTK_IM_MODULE=waylandgtk");
    return;
  }
  g_message("no Wayland text-input global; using the bundled Maliit module");
  use_bundled_maliit();
}

void log_im_context(GtkWidget* window) {
  GtkIMContext* im = gtk_im_multicontext_new();
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  if (gdk_window != nullptr) {
    gtk_im_context_set_client_window(im, gdk_window);
  }
  const char* id =
      gtk_im_multicontext_get_context_id(GTK_IM_MULTICONTEXT(im));
  const char* module = g_getenv("GTK_IM_MODULE");
  g_message("im context id=%s GTK_IM_MODULE=%s", id != nullptr ? id : "(null)",
            module != nullptr ? module : "(unset)");
  g_object_unref(im);
}

// Lomiri starts another process for a link because this runner is not a
// GtkApplication. The new process writes the URL here and exits before it
// creates a window. The process that already owns the socket keeps running.
bool is_launch_url(const char* arg) {
  return g_str_has_prefix(arg, "https://") ||
         g_str_has_prefix(arg, "http://") ||
         g_str_has_prefix(arg, "intent://") ||
         g_str_has_prefix(arg, "vnd.youtube:") ||
         g_str_has_prefix(arg, "youtube:");
}

const char* find_launch_url(int argc, char** argv) {
  for (int i = 1; i < argc; i++) {
    if (argv[i] == nullptr) continue;
    if (is_launch_url(argv[i])) return argv[i];
  }
  return nullptr;
}

std::string url_socket_path() {
  const char* data = g_get_user_data_dir();
  return std::string(data != nullptr ? data : "") +
         "/gastube.alphaliu01/url-dispatcher.sock";
}

bool fill_socket_address(const std::string& path, sockaddr_un* addr) {
  if (path.size() >= sizeof(addr->sun_path)) return false;
  std::memset(addr, 0, sizeof(*addr));
  addr->sun_family = AF_UNIX;
  std::memcpy(addr->sun_path, path.c_str(), path.size() + 1);
  return true;
}

bool forward_url(const char* url) {
  std::string path = url_socket_path();
  sockaddr_un addr;
  if (!fill_socket_address(path, &addr)) return false;
  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) return false;
  if (connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0) {
    close(fd);
    return false;
  }
  std::string line = std::string(url) + "\n";
  const char* data = line.data();
  size_t left = line.size();
  while (left > 0) {
    ssize_t wrote = write(fd, data, left);
    if (wrote < 0) {
      close(fd);
      return false;
    }
    data += wrote;
    left -= static_cast<size_t>(wrote);
  }
  close(fd);
  return true;
}

GMutex g_url_mutex;
std::vector<std::string> g_url_pending;
bool g_url_dart_ready = false;
FlMethodChannel* g_url_channel = nullptr;

gboolean emit_url(gpointer data) {
  char* url = static_cast<char*>(data);
  if (g_url_channel != nullptr) {
    g_autoptr(FlValue) args = fl_value_new_string(url);
    fl_method_channel_invoke_method(g_url_channel, "url", args, nullptr,
                                    nullptr, nullptr);
  }
  g_free(url);
  return G_SOURCE_REMOVE;
}

void keep_url(const std::string& url) {
  g_message("url received %s", url.c_str());
  g_mutex_lock(&g_url_mutex);
  bool ready = g_url_dart_ready;
  if (!ready) g_url_pending.push_back(url);
  g_mutex_unlock(&g_url_mutex);
  if (ready) g_idle_add(emit_url, g_strdup(url.c_str()));
}

gpointer url_accept_loop(gpointer data) {
  int listen_fd = GPOINTER_TO_INT(data);
  while (true) {
    int client = accept(listen_fd, nullptr, nullptr);
    if (client < 0) continue;
    std::string line;
    char buf[256];
    while (line.size() < 4096) {
      ssize_t got = read(client, buf, sizeof(buf));
      if (got <= 0) break;
      line.append(buf, buf + got);
      std::string::size_type end = line.find('\n');
      if (end != std::string::npos) {
        line.resize(end);
        break;
      }
    }
    close(client);
    if (!line.empty()) keep_url(line);
  }
  return nullptr;
}

void start_url_listener() {
  g_mutex_init(&g_url_mutex);
  std::string path = url_socket_path();
  g_autofree char* dir = g_path_get_dirname(path.c_str());
  if (g_mkdir_with_parents(dir, 0700) != 0) {
    g_warning("url directory failed path=%s error=%s", dir, g_strerror(errno));
    return;
  }
  unlink(path.c_str());
  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) {
    g_warning("url socket failed error=%s", g_strerror(errno));
    return;
  }
  sockaddr_un addr;
  if (!fill_socket_address(path, &addr) ||
      bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0 ||
      listen(fd, 4) != 0) {
    g_warning("url listen failed path=%s error=%s", path.c_str(),
              g_strerror(errno));
    close(fd);
    return;
  }
  g_message("url listen path=%s", path.c_str());
  // Keep the GThread for the life of the process. Releasing it now frees
  // the thread record while url_accept_loop is still inside it.
  static GThread* thread = nullptr;
  thread = g_thread_new("url", url_accept_loop, GINT_TO_POINTER(fd));
  (void)thread;
}

void url_method_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(call), "mediaHubSession") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    g_free(g_media_hub_uuid);
    g_media_hub_uuid = nullptr;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      const gchar* uuid = fl_value_get_string(args);
      if (uuid != nullptr && uuid[0] != '\0') g_media_hub_uuid = g_strdup(uuid);
    }
    g_message("gastube: mediahub session-note uuid=%s",
              g_media_hub_uuid != nullptr ? g_media_hub_uuid : "");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(call), "drain") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    g_mutex_lock(&g_url_mutex);
    for (const std::string& url : g_url_pending) {
      fl_value_append_take(list, fl_value_new_string(url.c_str()));
    }
    g_url_pending.clear();
    g_url_dart_ready = true;
    g_mutex_unlock(&g_url_mutex);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("url drain response failed: %s",
              error != nullptr ? error->message : "unknown");
  }
}

void install_url_channel(FlView* view) {
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_url_channel = fl_method_channel_new(messenger, "lol.alphaliu01.gastube/url",
                                        FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_url_channel, url_method_call,
                                            nullptr, nullptr);
}

}  // namespace

extern "C" void gastube_media_hub_on_exit() {
  destroy_media_hub_session();
}

void gastube_ut_set_scale(int scale);
extern "C" void gastube_ut_probe_media_codec();

// Lomiri gives this process a Wayland surface and libhybris EGL. GTK's
// default desktop GL context fails there; GLES is the context that painted
// the Phase 0 hello. The soft keyboard is Maliit over D-Bus, chosen after
// gtk_init once the Wayland registry is known.
extern "C" int gastube_ubuntu_touch_main(int argc, char** argv) {
  const char* launch_url = find_launch_url(argc, argv);
  if (launch_url != nullptr && forward_url(launch_url)) {
    g_message("url forwarded %s", launch_url);
    return 0;
  }
  start_url_listener();
  if (launch_url != nullptr) {
    g_message("url argv %s", launch_url);
  }

  install_fatal_signals();
  gastube_ut_probe_media_codec();
  setenv("GDK_GL", "gles", 1);
  clear_session_im_module();
  int scale = flutter_scale();
  gtk_init(&argc, &argv);
  choose_input_method();
  log_scale_environment();
  if (scale <= 1) {
    GdkMonitor* panel = choose_panel(gdk_display_get_default());
    scale = panel != nullptr ? scale_from_monitor_mm(panel) : 1;
    std::fprintf(stderr, "gastube: flutter scale %d from monitor size\n",
                 scale);
  }
  if (scale < 1) scale = 1;
  gastube_ut_set_scale(scale);
  g_message("flutter view scale=%d; Wayland output scale is left unchanged",
            scale);

  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "");
  g_signal_connect(window, "destroy", G_CALLBACK(on_destroy), nullptr);
  g_signal_connect(window, "configure-event", G_CALLBACK(on_configure), nullptr);
  g_signal_connect(window, "window-state-event", G_CALLBACK(on_window_state),
                   nullptr);
  use_application_stage(GTK_WINDOW(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, argv + 1);
  FlView* view = fl_view_new(project);
  GdkRGBA background = {1.0, 1.0, 1.0, 1.0};
  fl_view_set_background_color(view, &background);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  gastube_ut_install_present_hook(GTK_WIDGET(view));
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  install_url_channel(view);

  gtk_widget_show_all(window);
  use_application_stage(GTK_WINDOW(window));
  log_im_context(window);

  // Do not call gdk_window_create_gl_context. That installs GTK's paint GL
  // context, and every later expose uploads this white background and swaps
  // it onto the same wl_surface Impeller is presenting.
  g_message("GDK_GL=gles; paint context left unset so exposes do not swap white");

  g_unix_signal_add(SIGTERM, on_shutdown_signal, nullptr);
  g_unix_signal_add(SIGINT, on_shutdown_signal, nullptr);
  std::atexit(gastube_media_hub_on_exit);

  gtk_main();
  return 0;
}

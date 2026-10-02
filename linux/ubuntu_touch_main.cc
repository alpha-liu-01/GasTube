#include <flutter_linux/flutter_linux.h>

#include <gdk/gdk.h>
#include <gtk/gtk.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>

#include "flutter/generated_plugin_registrant.h"

namespace {

void on_destroy(GtkWidget*, gpointer) {
  gtk_main_quit();
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
  return FALSE;
}

}  // namespace

void gastube_ut_set_scale(int scale);

// Lomiri gives this process a Wayland surface and libhybris EGL. GTK's
// default desktop GL context fails there; GLES is the context that painted
// the Phase 0 hello. There is no GTK3 Maliit module on the 6T image.
extern "C" int gastube_ubuntu_touch_main(int argc, char** argv) {
  setenv("GDK_GL", "gles", 1);
  int scale = flutter_scale();
  gtk_init(&argc, &argv);
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
  FlView* view = fl_view_new(project);
  GdkRGBA background = {1.0, 1.0, 1.0, 1.0};
  fl_view_set_background_color(view, &background);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_show_all(window);
  use_application_stage(GTK_WINDOW(window));

  GdkWindow* gdk_window = gtk_widget_get_window(window);
  g_autoptr(GError) error = nullptr;
  GdkGLContext* context = gdk_window_create_gl_context(gdk_window, &error);
  if (context == nullptr) {
    g_warning("GDK_GL=gles context failed: %s",
              error != nullptr ? error->message : "unknown");
  } else {
    g_message("GDK_GL=gles context created");
    g_object_unref(context);
  }

  gtk_main();
  return 0;
}

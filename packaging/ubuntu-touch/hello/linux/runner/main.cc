#include <flutter_linux/flutter_linux.h>

#include <gdk/gdk.h>
#include <gtk/gtk.h>

#include <cstdlib>

#include "flutter/generated_plugin_registrant.h"

namespace {

void OnDestroy(GtkWidget* widget, gpointer data) {
  (void)widget;
  (void)data;
  gtk_main_quit();
}

}  // namespace

// Ubuntu Touch denies GtkApplication's D-Bus RequestName. The GTK probe
// already confirmed that, so this hello uses a plain GtkWindow and still
// embeds the Flutter view.
//
// Lomiri's EGL driver is libhybris, which provides OpenGL ES rather than
// desktop GL. GTK otherwise asks for a desktop GL context and fails, leaving
// the Flutter view at its background color.
int main(int argc, char** argv) {
  setenv("GDK_GL", "gles", 1);
  gtk_init(&argc, &argv);

  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "GasTube Hello");
  gtk_window_set_default_size(GTK_WINDOW(window), 1280, 720);
  g_signal_connect(window, "destroy", G_CALLBACK(OnDestroy), nullptr);
  gtk_widget_realize(window);

  GError* gl_error = nullptr;
  GdkGLContext* gl_context = gdk_window_create_gl_context(
      gtk_widget_get_window(window), &gl_error);
  if (gl_context == nullptr) {
    g_warning("GDK_GL=gles context failed: %s", gl_error->message);
    g_clear_error(&gl_error);
  } else {
    g_message("GDK_GL=gles context created");
    g_object_unref(gl_context);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, argv + 1);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#FFFFFF");
  fl_view_set_background_color(view, &background_color);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  gtk_widget_grab_focus(GTK_WIDGET(view));
  gtk_widget_show_all(window);

  gtk_main();
  return 0;
}

/* Reads the EGL extension string from the same GTK GLES context GasTube uses.
   Built for Ubuntu 20.04 arm64 and run on the phone; not part of the Click. */
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>

static void print_string(const char* label, const char* value) {
  printf("%s=%s\n", label, value != NULL ? value : "(null)");
}

static gboolean probe(gpointer user_data) {
  GtkWidget* window = GTK_WIDGET(user_data);
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  if (gdk_window == NULL) {
    fprintf(stderr, "no gdk window\n");
    gtk_main_quit();
    return G_SOURCE_REMOVE;
  }

  GError* error = NULL;
  GdkGLContext* context = gdk_window_create_gl_context(gdk_window, &error);
  if (context == NULL || !gdk_gl_context_realize(context, &error)) {
    fprintf(stderr, "gl context failed: %s\n",
            error != NULL ? error->message : "unknown");
    gtk_main_quit();
    return G_SOURCE_REMOVE;
  }
  gdk_gl_context_make_current(context);

  EGLDisplay display = eglGetCurrentDisplay();
  print_string("EGL_VENDOR", eglQueryString(display, EGL_VENDOR));
  print_string("EGL_VERSION", eglQueryString(display, EGL_VERSION));
  print_string("EGL_CLIENT_APIS", eglQueryString(display, EGL_CLIENT_APIS));
  print_string("EGL_EXTENSIONS", eglQueryString(display, EGL_EXTENSIONS));
  print_string("EGL_CLIENT_EXTENSIONS",
               eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS));
  print_string("GL_VENDOR", (const char*)glGetString(GL_VENDOR));
  print_string("GL_RENDERER", (const char*)glGetString(GL_RENDERER));
  print_string("GL_VERSION", (const char*)glGetString(GL_VERSION));
  fflush(stdout);
  gtk_main_quit();
  return G_SOURCE_REMOVE;
}

static gboolean timed_out(gpointer user_data) {
  fprintf(stderr, "timed out waiting for a GL context\n");
  gtk_main_quit();
  return G_SOURCE_REMOVE;
}

static void on_map(GtkWidget* window, gpointer user_data) {
  g_idle_add(probe, window);
}

int main(int argc, char** argv) {
  g_setenv("GDK_GL", "gles", TRUE);
  gtk_init(&argc, &argv);
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window), 64, 64);
  g_signal_connect(window, "map", G_CALLBACK(on_map), NULL);
  g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
  g_timeout_add_seconds(8, timed_out, NULL);
  gtk_widget_show_all(window);
  gtk_main();
  return 0;
}

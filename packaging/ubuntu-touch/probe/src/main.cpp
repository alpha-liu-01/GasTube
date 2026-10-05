#include <gtk/gtk.h>

#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <gnu/libc-version.h>

#include <sys/utsname.h>

#include <cstdio>
#include <cstring>
#include <string>

std::string ProbeText() {
  utsname name = {};
  uname(&name);
  char buffer[512];
  std::snprintf(
      buffer,
      sizeof(buffer),
      "machine: %s\nglibc: %s\nGTK: %u.%u.%u",
      name.machine,
      gnu_get_libc_version(),
      gtk_get_major_version(),
      gtk_get_minor_version(),
      gtk_get_micro_version());
  return buffer;
}

void NoteExtension(std::string& text, const char* extensions, const char* name) {
  const bool present =
      extensions != nullptr && std::strstr(extensions, name) != nullptr;
  text += name;
  text += present ? ": yes\n" : ": no\n";
}

std::string EglText(GdkWindow* window) {
  GError* error = nullptr;
  GdkGLContext* context = gdk_window_create_gl_context(window, &error);
  if (context == nullptr || !gdk_gl_context_realize(context, &error)) {
    std::string message = "GL context failed: ";
    message += error != nullptr ? error->message : "unknown";
    return message;
  }
  gdk_gl_context_make_current(context);

  EGLDisplay display = eglGetCurrentDisplay();
  const char* extensions = eglQueryString(display, EGL_EXTENSIONS);
  std::string text;
  auto add = [&text](const char* label, const char* value) {
    text += label;
    text += "=";
    text += value != nullptr ? value : "(null)";
    text += "\n";
  };
  add("EGL_VENDOR", eglQueryString(display, EGL_VENDOR));
  add("EGL_VERSION", eglQueryString(display, EGL_VERSION));
  add("GL_RENDERER", reinterpret_cast<const char*>(glGetString(GL_RENDERER)));
  add("GL_VERSION", reinterpret_cast<const char*>(glGetString(GL_VERSION)));
  NoteExtension(text, extensions, "EGL_EXT_buffer_age");
  NoteExtension(text, extensions, "EGL_KHR_partial_update");
  NoteExtension(text, extensions, "EGL_KHR_swap_buffers_with_damage");
  NoteExtension(text, extensions, "EGL_EXT_swap_buffers_with_damage");
  text += "EGL_EXTENSIONS=";
  text += extensions != nullptr ? extensions : "(null)";
  text += "\n";
  return text;
}

gboolean LogEgl(gpointer user_data) {
  GtkWidget* window = GTK_WIDGET(user_data);
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  std::string text = gdk_window != nullptr ? EglText(gdk_window)
                                           : std::string("no gdk window\n");
  std::fprintf(stderr, "%s", text.c_str());
  g_message("%s", text.c_str());
  GtkWidget* label = GTK_WIDGET(g_object_get_data(G_OBJECT(window), "label"));
  if (label != nullptr) {
    gtk_label_set_text(GTK_LABEL(label), text.c_str());
  }
  return G_SOURCE_REMOVE;
}

void OnMap(GtkWidget* window, gpointer) {
  g_idle_add(LogEgl, window);
}

int main(int argc, char** argv) {
  g_setenv("GDK_GL", "gles", TRUE);
  gtk_init(&argc, &argv);

  const std::string text = ProbeText();
  std::fprintf(stdout, "%s\n", text.c_str());

  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "GasTube Probe");
  gtk_window_set_default_size(GTK_WINDOW(window), 360, 640);
  g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), nullptr);

  GtkWidget* label = gtk_label_new(text.c_str());
  gtk_label_set_selectable(GTK_LABEL(label), TRUE);
  gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_LEFT);
  gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
  g_object_set_data(G_OBJECT(window), "label", label);
  g_signal_connect(window, "map", G_CALLBACK(OnMap), nullptr);
  gtk_container_add(GTK_CONTAINER(window), label);
  gtk_widget_show_all(window);

  gtk_main();
  return 0;
}

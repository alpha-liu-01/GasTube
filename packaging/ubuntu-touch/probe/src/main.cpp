#include <gtk/gtk.h>

#include <gnu/libc-version.h>

#include <sys/utsname.h>

#include <cstdio>
#include <string>

namespace {

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

}  // namespace

int main(int argc, char** argv) {
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
  gtk_container_add(GTK_CONTAINER(window), label);
  gtk_widget_show_all(window);

  gtk_main();
  return 0;
}

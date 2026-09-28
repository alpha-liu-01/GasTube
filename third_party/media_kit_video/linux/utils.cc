// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/utils.h"

// The Linux runner installs a client-side header bar outside GNOME-on-X11.
// gtk_window_fullscreen leaves that bar on screen. Unsetting it with
// gtk_window_set_titlebar on an already-open window recreates the GDK
// surface and Flutter's GL context dies (blank fullscreen, then the app
// has to be killed). Hide the bar instead; it stays parented to the window.
static GtkWidget* hidden_titlebar = nullptr;
static gboolean app_fullscreen = FALSE;

void utils_set_app_fullscreen(gboolean enabled) {
  app_fullscreen = enabled;
}

void utils_enter_native_fullscreen(GtkWidget* window) {
  if (!GTK_IS_WINDOW(window)) {
    return;
  }
  GtkWindow* gtk_window = GTK_WINDOW(window);
  GtkWidget* titlebar = gtk_window_get_titlebar(gtk_window);
  if (titlebar != nullptr && hidden_titlebar == nullptr &&
      gtk_widget_get_visible(titlebar)) {
    hidden_titlebar = titlebar;
    gtk_widget_hide(hidden_titlebar);
  }
  gtk_window_fullscreen(gtk_window);
}

void utils_exit_native_fullscreen(GtkWidget* window) {
  if (app_fullscreen || !GTK_IS_WINDOW(window)) {
    return;
  }
  gtk_window_unfullscreen(GTK_WINDOW(window));
  if (hidden_titlebar != nullptr) {
    gtk_widget_show(hidden_titlebar);
    hidden_titlebar = nullptr;
  }
}

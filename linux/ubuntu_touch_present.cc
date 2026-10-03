#include <gdk/gdk.h>
#include <gtk/gtk.h>

#include <EGL/egl.h>
#include <wayland-client.h>

#include <dlfcn.h>

#include <algorithm>
#include <atomic>
#include <cstdarg>
#include <vector>

// Official full-frame engine. The window is always invalidated in full.
// Frame time is split in two places:
//   gastube: frame  — UI build and raster, from the engine. Raster ends when
//                     the compositor FBO is ready. It does not include the
//                     later GTK copy.
//   present: blit   — gdk_cairo_draw_from_gl, the full-texture copy into the
//                     window, plus the GTK draw that wraps it and the gap
//                     between draws.
// libflutter calls gdk_cairo_draw_from_gl, so this executable can interpose
// it. epoxy_eglQuerySurface is a function pointer. Do not define it.

namespace {

constexpr double kBudgetMs = 16.7;
constexpr gint64 kReportUs = 1000000;

using DrawFromGlFn = void (*)(cairo_t*, GdkWindow*, int, int, int, int, int,
                              int, int);

struct Samples {
  std::vector<double> values;

  void add(double ms) { values.push_back(ms); }

  void clear() { values.clear(); }

  int count() const { return static_cast<int>(values.size()); }

  double average() const {
    if (values.empty()) return 0;
    double sum = 0;
    for (double value : values) sum += value;
    return sum / static_cast<double>(values.size());
  }

  double max() const {
    if (values.empty()) return 0;
    return *std::max_element(values.begin(), values.end());
  }

  int over_budget() const {
    int count = 0;
    for (double value : values) {
      if (value > kBudgetMs) count++;
    }
    return count;
  }
};

Samples g_blit_ms;
Samples g_draw_ms;
Samples g_interval_ms;
gint64 g_last_draw_us = 0;
gint64 g_last_report_us = 0;
int g_blit_w = 0;
int g_blit_h = 0;

// The engine calls these function pointers in libepoxy. Assigning them gates
// present. Do not define the epoxy_* symbols; a definition here is the wrong
// object and faults when the engine calls through it.
extern "C" EGLBoolean (*epoxy_eglSwapBuffers)(EGLDisplay, EGLSurface);
extern "C" EGLBoolean (*epoxy_eglMakeCurrent)(EGLDisplay, EGLSurface,
                                              EGLSurface, EGLContext);

using EglSwapFn = EGLBoolean (*)(EGLDisplay, EGLSurface);
using EglMakeCurrentFn = EGLBoolean (*)(EGLDisplay, EGLSurface, EGLSurface,
                                        EGLContext);

std::atomic<bool> g_present_allowed{true};
// Set while the window is covered, and kept set until the first real swap
// after it is shown again. GTK's expose clears a white paint buffer and
// attaches it before that swap, which is the one white frame on the way back.
std::atomic<bool> g_hold_expose{false};
std::atomic<bool> g_logged_skip{false};
std::atomic<bool> g_logged_make_current{false};
std::atomic<bool> g_logged_flush{false};
std::atomic<bool> g_logged_expose{false};
std::atomic<bool> g_logged_shell{false};
std::atomic<int> g_in_real_swap{0};
EglSwapFn g_real_swap = nullptr;
EglMakeCurrentFn g_real_make_current = nullptr;

extern "C" EGLBoolean gastube_gated_egl_swap(EGLDisplay display,
                                            EGLSurface surface) {
  if (!g_present_allowed.load(std::memory_order_acquire)) {
    bool already = g_logged_skip.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message(
          "present: skipped eglSwapBuffers while the window is unfocused");
    }
    return EGL_TRUE;
  }
  if (g_real_swap == nullptr) return EGL_FALSE;
  // GTK's paint commits a transparent wl_buffer through wl_proxy_marshal.
  // That commit is what shows the wallpaper. The swap's own attach has to
  // go through, so mark this call.
  g_in_real_swap.fetch_add(1, std::memory_order_acq_rel);
  EGLBoolean ok = g_real_swap(display, surface);
  g_in_real_swap.fetch_sub(1, std::memory_order_acq_rel);
  if (ok == EGL_TRUE) {
    g_hold_expose.store(false, std::memory_order_release);
  }
  return ok;
}

extern "C" EGLBoolean gastube_gated_egl_make_current(EGLDisplay display,
                                                    EGLSurface draw,
                                                    EGLSurface read,
                                                    EGLContext context) {
  // Surfaceless calls still run. Those release the context. Binding the
  // window surface while Lomiri is covering it is what drops the last frame.
  if (!g_present_allowed.load(std::memory_order_acquire) &&
      draw != EGL_NO_SURFACE && read != EGL_NO_SURFACE) {
    bool already =
        g_logged_make_current.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message(
          "present: skipped eglMakeCurrent while the window is unfocused");
    }
    return EGL_FALSE;
  }
  if (g_real_make_current == nullptr) return EGL_FALSE;
  return g_real_make_current(display, draw, read, context);
}

void install_swap_gate() {
  if (g_real_swap == nullptr) {
    g_real_swap =
        reinterpret_cast<EglSwapFn>(dlsym(RTLD_NEXT, "eglSwapBuffers"));
    if (g_real_swap == nullptr || epoxy_eglSwapBuffers == nullptr) {
      g_warning("present: eglSwapBuffers gate left off (%s)",
                g_real_swap == nullptr ? "dlsym" : "epoxy");
      g_real_swap = nullptr;
    } else {
      epoxy_eglSwapBuffers = gastube_gated_egl_swap;
      g_message("present: eglSwapBuffers gated on window focus");
    }
  }
  if (g_real_make_current == nullptr) {
    g_real_make_current = reinterpret_cast<EglMakeCurrentFn>(
        dlsym(RTLD_NEXT, "eglMakeCurrent"));
    if (g_real_make_current == nullptr || epoxy_eglMakeCurrent == nullptr) {
      g_warning("present: eglMakeCurrent gate left off (%s)",
                g_real_make_current == nullptr ? "dlsym" : "epoxy");
      g_real_make_current = nullptr;
    } else {
      epoxy_eglMakeCurrent = gastube_gated_egl_make_current;
      g_message("present: eglMakeCurrent gated on window focus");
    }
  }
}

double ms_from_us(gint64 us) { return static_cast<double>(us) / 1000.0; }

void report_if_due(gint64 now) {
  if (g_last_report_us == 0) g_last_report_us = now;
  if (now - g_last_report_us < kReportUs) return;
  if (g_blit_ms.count() == 0 && g_draw_ms.count() == 0) {
    g_last_report_us = now;
    return;
  }
  g_message(
      "present: blit n=%d avg=%.2f max=%.2f over16=%d "
      "draw n=%d avg=%.2f max=%.2f over16=%d "
      "interval n=%d avg=%.2f max=%.2f over16=%d size=%dx%d",
      g_blit_ms.count(), g_blit_ms.average(), g_blit_ms.max(),
      g_blit_ms.over_budget(), g_draw_ms.count(), g_draw_ms.average(),
      g_draw_ms.max(), g_draw_ms.over_budget(), g_interval_ms.count(),
      g_interval_ms.average(), g_interval_ms.max(),
      g_interval_ms.over_budget(), g_blit_w, g_blit_h);
  g_blit_ms.clear();
  g_draw_ms.clear();
  g_interval_ms.clear();
  g_last_report_us = now;
}

void note_blit(gint64 us, int width, int height) {
  g_blit_ms.add(ms_from_us(us));
  g_blit_w = width;
  g_blit_h = height;
  report_if_due(g_get_monotonic_time());
}

void note_draw(gint64 us, gint64 now) {
  g_draw_ms.add(ms_from_us(us));
  if (g_last_draw_us != 0) {
    g_interval_ms.add(ms_from_us(now - g_last_draw_us));
  }
  g_last_draw_us = now;
  report_if_due(now);
}

using WidgetDrawFn = gboolean (*)(GtkWidget*, cairo_t*);

WidgetDrawFn g_original_draw = nullptr;

GtkWidget* g_renderer = nullptr;

bool expose_held();

gboolean timed_draw(GtkWidget* widget, cairo_t* cr) {
  if (expose_held()) {
    return TRUE;
  }
  gint64 start = g_get_monotonic_time();
  gboolean result = FALSE;
  if (g_original_draw != nullptr) result = g_original_draw(widget, cr);
  gint64 now = g_get_monotonic_time();
  note_draw(now - start, now);
  return result;
}

WidgetDrawFn g_original_window_draw = nullptr;
WidgetDrawFn g_original_view_draw = nullptr;

bool expose_held() {
  return !g_present_allowed.load(std::memory_order_acquire) ||
         g_hold_expose.load(std::memory_order_acquire);
}

gboolean draw_or_hold(GtkWidget* widget, cairo_t* cr, WidgetDrawFn original) {
  if (expose_held()) {
    bool already = g_logged_expose.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message("present: skipped expose while the window is unfocused");
    }
    return TRUE;
  }
  if (original != nullptr) return original(widget, cr);
  return FALSE;
}

gboolean drop_expose_before_paint(GtkWidget*, GdkEvent* event, gpointer) {
  if (!expose_held()) return FALSE;
  if (event->type != GDK_EXPOSE && event->type != GDK_DAMAGE) return FALSE;
  bool already = g_logged_expose.exchange(true, std::memory_order_relaxed);
  if (!already) {
    g_message("present: dropped expose until the resumed swap");
  }
  return TRUE;
}

void watch_expose(GtkWidget* widget) {
  if (widget == nullptr) return;
  g_signal_connect(widget, "event", G_CALLBACK(drop_expose_before_paint),
                   nullptr);
}

gboolean hold_window_draw(GtkWidget* widget, cairo_t* cr) {
  return draw_or_hold(widget, cr, g_original_window_draw);
}

gboolean hold_view_draw(GtkWidget* widget, cairo_t* cr) {
  return draw_or_hold(widget, cr, g_original_view_draw);
}

void find_renderer(GtkWidget* widget, gpointer data) {
  auto** found = static_cast<GtkWidget**>(data);
  if (*found != nullptr || widget == nullptr) return;
  if (g_strcmp0(G_OBJECT_TYPE_NAME(widget), "FlViewRenderer") == 0) {
    *found = widget;
    return;
  }
  if (GTK_IS_CONTAINER(widget)) {
    gtk_container_forall(GTK_CONTAINER(widget), find_renderer, data);
  }
}

DrawFromGlFn real_draw_from_gl() {
  static DrawFromGlFn fn = nullptr;
  if (fn == nullptr) {
    fn = reinterpret_cast<DrawFromGlFn>(dlsym(RTLD_NEXT, "gdk_cairo_draw_from_gl"));
  }
  return fn;
}

}  // namespace

extern "C" void gdk_cairo_draw_from_gl(cairo_t* cr, GdkWindow* window,
                                       int source, int source_type,
                                       int buffer_scale, int x, int y,
                                       int width, int height) {
  DrawFromGlFn fn = real_draw_from_gl();
  gint64 start = g_get_monotonic_time();
  if (fn != nullptr) {
    fn(cr, window, source, source_type, buffer_scale, x, y, width, height);
  }
  note_blit(g_get_monotonic_time() - start, width, height);
}

void gastube_ut_install_present_hook(GtkWidget* view) {
  install_swap_gate();
  GtkWidget* top = gtk_widget_get_toplevel(view);
  if (top != nullptr && top != view && g_original_window_draw == nullptr) {
    GtkWidgetClass* window_class = GTK_WIDGET_GET_CLASS(top);
    g_original_window_draw = window_class->draw;
    window_class->draw = hold_window_draw;
    watch_expose(top);
  }
  if (g_original_view_draw == nullptr) {
    GtkWidgetClass* view_class = GTK_WIDGET_GET_CLASS(view);
    g_original_view_draw = view_class->draw;
    view_class->draw = hold_view_draw;
    watch_expose(view);
  }
  GtkWidget* renderer = nullptr;
  find_renderer(view, &renderer);
  if (renderer != nullptr && g_original_draw == nullptr) {
    g_renderer = renderer;
    watch_expose(renderer);
    // The draw vfunc returns TRUE, which stops the signal before an
    // after-handler would run. Wrap the class handler instead.
    GtkWidgetClass* klass = GTK_WIDGET_GET_CLASS(renderer);
    g_original_draw = klass->draw;
    klass->draw = timed_draw;
  }
  g_message(
      "present: full frame; window invalidate is full; "
      "timing build/raster, the vsync gap, and gdk_cairo_draw_from_gl%s",
      renderer != nullptr ? "" : " (FlViewRenderer not found)");
}

void gastube_ut_set_present_allowed(bool allowed) {
  bool previous = g_present_allowed.exchange(allowed, std::memory_order_release);
  if (previous == allowed) return;
  g_logged_skip.store(false, std::memory_order_relaxed);
  g_logged_make_current.store(false, std::memory_order_relaxed);
  g_logged_flush.store(false, std::memory_order_relaxed);
  g_logged_expose.store(false, std::memory_order_relaxed);
  g_logged_shell.store(false, std::memory_order_relaxed);
  if (!allowed) {
    g_hold_expose.store(true, std::memory_order_release);
  } else if (g_renderer != nullptr && g_original_draw != nullptr) {
    // Schedule the frame the expose would have scheduled. Calling the
    // renderer draw from here does not enter GDK begin_paint, so it does
    // not attach the white buffer. The onscreen draw only schedules.
    g_original_draw(g_renderer, nullptr);
    g_message("present: scheduled frame without a GTK paint");
  }
  g_message("present: %s", allowed ? "resume swap" : "pause swap");
}

// Wayland 1.0 wl_surface opcodes. Focal GDK inlines wl_surface_attach and
// wl_surface_commit into wl_proxy_marshal, so this is the call to filter.
constexpr uint32_t kWlSurfaceAttach = 1;
constexpr uint32_t kWlSurfaceCommit = 6;
constexpr int kWlMaxArgs = 20;

struct ArgDetails {
  char type;
  int nullable;
};

const char* next_wl_argument(const char* signature, ArgDetails* details) {
  details->nullable = 0;
  for (; signature != nullptr && *signature != '\0'; ++signature) {
    switch (*signature) {
      case 'i':
      case 'u':
      case 'f':
      case 's':
      case 'o':
      case 'n':
      case 'a':
      case 'h':
        details->type = *signature;
        return signature + 1;
      case '?':
        details->nullable = 1;
        break;
      default:
        break;
    }
  }
  details->type = '\0';
  return signature;
}

void fill_wl_arguments(const char* signature, union wl_argument* args, int count,
                       va_list ap) {
  for (int i = 0; i < count; i++) {
    ArgDetails arg;
    signature = next_wl_argument(signature, &arg);
    switch (arg.type) {
      case 'i':
        args[i].i = va_arg(ap, int32_t);
        break;
      case 'u':
        args[i].u = va_arg(ap, uint32_t);
        break;
      case 'f':
        args[i].f = va_arg(ap, wl_fixed_t);
        break;
      case 's':
        args[i].s = va_arg(ap, const char*);
        break;
      case 'o':
      case 'n':
        args[i].o = va_arg(ap, struct wl_object*);
        break;
      case 'a':
        args[i].a = va_arg(ap, struct wl_array*);
        break;
      case 'h':
        args[i].h = va_arg(ap, int32_t);
        break;
      case '\0':
        return;
      default:
        return;
    }
  }
}

bool drop_surface_update(struct wl_proxy* proxy, uint32_t opcode) {
  if (!g_hold_expose.load(std::memory_order_acquire)) return false;
  if (g_in_real_swap.load(std::memory_order_acquire) != 0) return false;
  if (proxy == nullptr) return false;
  if (opcode != kWlSurfaceAttach && opcode != kWlSurfaceCommit) return false;
  const auto* iface =
      *reinterpret_cast<const struct wl_interface* const*>(proxy);
  if (iface != &wl_surface_interface) return false;
  bool already = g_logged_shell.exchange(true, std::memory_order_relaxed);
  if (!already) {
    g_message(
        "present: skipped wl_surface attach/commit while the last frame is held");
  }
  return true;
}

extern "C" void wl_proxy_marshal(struct wl_proxy* proxy, uint32_t opcode, ...) {
  if (drop_surface_update(proxy, opcode)) return;

  const auto* iface =
      proxy == nullptr
          ? nullptr
          : *reinterpret_cast<const struct wl_interface* const*>(proxy);
  union wl_argument args[kWlMaxArgs];
  va_list ap;
  va_start(ap, opcode);
  if (iface != nullptr && opcode < static_cast<uint32_t>(iface->method_count)) {
    fill_wl_arguments(iface->methods[opcode].signature, args, kWlMaxArgs, ap);
  }
  va_end(ap);

  using MarshalArrayFn = struct wl_proxy* (*)(struct wl_proxy*, uint32_t,
                                              union wl_argument*,
                                              const struct wl_interface*);
  static MarshalArrayFn real = nullptr;
  if (real == nullptr) {
    real = reinterpret_cast<MarshalArrayFn>(
        dlsym(RTLD_NEXT, "wl_proxy_marshal_array_constructor"));
  }
  if (real != nullptr) real(proxy, opcode, args, nullptr);
}

extern "C" int wl_display_flush(struct wl_display* display) {
  if (!g_present_allowed.load(std::memory_order_acquire)) {
    bool already = g_logged_flush.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message("present: skipped wl_display_flush");
    }
    return 0;
  }
  using FlushFn = int (*)(struct wl_display*);
  static FlushFn real = nullptr;
  if (real == nullptr) {
    real = reinterpret_cast<FlushFn>(dlsym(RTLD_NEXT, "wl_display_flush"));
  }
  if (real == nullptr) return -1;
  return real(display);
}

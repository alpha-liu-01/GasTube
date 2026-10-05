#include <gdk/gdk.h>
#include <gtk/gtk.h>

#include <EGL/egl.h>
#include <wayland-client.h>

#include <dlfcn.h>
#include <pthread.h>

#include <algorithm>
#include <atomic>
#include <cstdarg>
#include <cstring>
#include <vector>

// Flutter's present and GDK's present both enter hybris on this window, and
// a resize cancels the buffer the other side still has queued. finishSwap
// then writes the freed buffer. One lock covers eglSwapBuffers and
// eglSwapBuffersWithDamageEXT. A resize that arrives on the same thread
// while a swap holds the lock is stored and applied after that swap returns,
// so it does not free the buffer finishSwap is still using. The apply must
// not re-enter this hook: hybris can dispatch another configure from inside
// the resize, and that would call the hook again.
struct wl_egl_window;
using WlEglResizeFn = void (*)(struct wl_egl_window*, int, int, int, int);

pthread_mutex_t g_hybris_window;
pthread_once_t g_hybris_window_once = PTHREAD_ONCE_INIT;
int g_hybris_depth = 0;
bool g_resize_pending = false;
struct wl_egl_window* g_resize_window = nullptr;
int g_resize_w = 0;
int g_resize_h = 0;
int g_resize_dx = 0;
int g_resize_dy = 0;
WlEglResizeFn g_real_wl_resize = nullptr;
bool g_applying_resize = false;

void init_hybris_window_lock() {
  pthread_mutexattr_t attr;
  pthread_mutexattr_init(&attr);
  pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(&g_hybris_window, &attr);
  pthread_mutexattr_destroy(&attr);
}

void lock_hybris_window() {
  pthread_once(&g_hybris_window_once, init_hybris_window_lock);
  pthread_mutex_lock(&g_hybris_window);
  g_hybris_depth++;
}

void unlock_hybris_window() {
  if (g_hybris_depth == 1 && g_resize_pending &&
      g_real_wl_resize != nullptr && !g_applying_resize) {
    g_applying_resize = true;
    // One nested configure can update the saved size. A second pass applies
    // that size. Further re-entry is dropped so this cannot loop.
    for (int pass = 0; pass < 2 && g_resize_pending; pass++) {
      g_resize_pending = false;
      struct wl_egl_window* window = g_resize_window;
      int width = g_resize_w;
      int height = g_resize_h;
      int dx = g_resize_dx;
      int dy = g_resize_dy;
      g_real_wl_resize(window, width, height, dx, dy);
    }
    g_resize_pending = false;
    g_applying_resize = false;
  }
  g_hybris_depth--;
  pthread_mutex_unlock(&g_hybris_window);
}

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
extern "C" EGLBoolean (*epoxy_eglSwapBuffersWithDamageEXT)(EGLDisplay,
                                                          EGLSurface, EGLint*,
                                                          EGLint);
extern "C" EGLBoolean (*epoxy_eglMakeCurrent)(EGLDisplay, EGLSurface,
                                              EGLSurface, EGLContext);

using EglSwapFn = EGLBoolean (*)(EGLDisplay, EGLSurface);
using EglSwapDamageFn = EGLBoolean (*)(EGLDisplay, EGLSurface, EGLint*, EGLint);
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
EglSwapDamageFn g_real_swap_damage = nullptr;
EglMakeCurrentFn g_real_make_current = nullptr;
pthread_t g_gtk_thread{};
bool g_gtk_thread_known = false;

bool on_gtk_thread() {
  return g_gtk_thread_known && pthread_equal(g_gtk_thread, pthread_self());
}

extern "C" EGLBoolean gastube_gated_egl_swap_damage(EGLDisplay display,
                                                   EGLSurface surface,
                                                   EGLint* rects,
                                                   EGLint n_rects);

// epoxy_eglSwapBuffersWithDamageEXT starts as a resolver. That resolver
// tail-calls whatever is currently in the same slot. Saving the resolver
// and then storing our gate in the slot makes the first call recurse until
// the stack overflows, which is the enter-fullscreen crash with no
// backtrace. The real entry point has to come from libEGL.
EglSwapDamageFn real_damage_swap() {
  void* egl = dlopen("libEGL.so.1", RTLD_NOW | RTLD_NOLOAD);
  if (egl == nullptr) egl = dlopen("libEGL.so.1", RTLD_NOW);
  if (egl == nullptr) return nullptr;
  using GetProc = void* (*)(const char*);
  auto get_proc = reinterpret_cast<GetProc>(dlsym(egl, "eglGetProcAddress"));
  if (get_proc == nullptr) return nullptr;
  void* fn = get_proc("eglSwapBuffersWithDamageEXT");
  if (fn == nullptr ||
      fn == reinterpret_cast<void*>(gastube_gated_egl_swap_damage)) {
    return nullptr;
  }
  // Mesa's loader can answer before hybris is current. Calling that
  // pointer on the hybris surface faults. Only the hybris entry is safe,
  // and it is not the epoxy resolver that tail-calls this slot.
  Dl_info info{};
  if (dladdr(fn, &info) == 0 || info.dli_fname == nullptr ||
      std::strstr(info.dli_fname, "hybris") == nullptr) {
    return nullptr;
  }
  return reinterpret_cast<EglSwapDamageFn>(fn);
}

bool g_logged_damage_lookup = false;

void install_damage_gate() {
  if (g_real_swap_damage != nullptr) return;
  if (epoxy_eglSwapBuffersWithDamageEXT == nullptr ||
      epoxy_eglSwapBuffersWithDamageEXT == gastube_gated_egl_swap_damage) {
    return;
  }
  EglSwapDamageFn real = real_damage_swap();
  if (real == nullptr) {
    if (!g_logged_damage_lookup) {
      g_logged_damage_lookup = true;
      g_message(
          "present: eglSwapBuffersWithDamageEXT left on epoxy's resolver");
    }
    return;
  }
  g_real_swap_damage = real;
  epoxy_eglSwapBuffersWithDamageEXT = gastube_gated_egl_swap_damage;
  Dl_info info{};
  const char* from = "libEGL";
  if (dladdr(reinterpret_cast<void*>(real), &info) != 0 &&
      info.dli_fname != nullptr) {
    from = info.dli_fname;
  }
  g_message("present: eglSwapBuffersWithDamageEXT gated via %s", from);
}

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
  if (g_real_swap == nullptr) {
    g_real_swap =
        reinterpret_cast<EglSwapFn>(dlsym(RTLD_NEXT, "eglSwapBuffers"));
  }
  if (g_real_swap == nullptr) return EGL_FALSE;
  install_damage_gate();
  // GTK's paint commits a transparent wl_buffer through wl_proxy_marshal.
  // That commit is what shows the wallpaper. The swap's own attach has to
  // go through, so mark this call.
  lock_hybris_window();
  g_in_real_swap.fetch_add(1, std::memory_order_acq_rel);
  EGLBoolean ok = g_real_swap(display, surface);
  g_in_real_swap.fetch_sub(1, std::memory_order_acq_rel);
  unlock_hybris_window();
  if (ok == EGL_TRUE) {
    g_hold_expose.store(false, std::memory_order_release);
  }
  return ok;
}

// GDK's fullscreen exit paints through this entry, not eglSwapBuffers. It
// reaches the same finishSwap. Leaving it ungated lets that paint race the
// resize that puts the panel back.
extern "C" EGLBoolean gastube_gated_egl_swap_damage(EGLDisplay display,
                                                   EGLSurface surface,
                                                   EGLint* rects,
                                                   EGLint n_rects) {
  if (!g_present_allowed.load(std::memory_order_acquire)) {
    bool already = g_logged_skip.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message(
          "present: skipped eglSwapBuffersWithDamageEXT while the window is unfocused");
    }
    return EGL_TRUE;
  }
  if (g_real_swap_damage == nullptr) return EGL_FALSE;
  lock_hybris_window();
  g_in_real_swap.fetch_add(1, std::memory_order_acq_rel);
  EGLBoolean ok = g_real_swap_damage(display, surface, rects, n_rects);
  g_in_real_swap.fetch_sub(1, std::memory_order_acq_rel);
  unlock_hybris_window();
  if (ok == EGL_TRUE) {
    g_hold_expose.store(false, std::memory_order_release);
  }
  return ok;
}

extern "C" EGLBoolean gastube_gated_egl_make_current(EGLDisplay display,
                                                    EGLSurface draw,
                                                    EGLSurface read,
                                                    EGLContext context) {
  // The raster thread keeps the context it asked for. Swap and the surface
  // commit stay gated, so that frame is not attached.
  // Creating another context here faults the hybris driver while the raster
  // thread is still inside a GL call. The window paint context is detached
  // while unfocused, so this thread should not draw. Leave EGL alone.
  if (!g_present_allowed.load(std::memory_order_acquire)) {
    if (!on_gtk_thread()) {
      if (g_real_make_current == nullptr) return EGL_FALSE;
      return g_real_make_current(display, draw, read, context);
    }
    (void)display;
    (void)draw;
    (void)read;
    (void)context;
    bool already =
        g_logged_make_current.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message(
          "present: left the egl context unchanged while the window is unfocused");
    }
    return EGL_TRUE;
  }
  if (g_real_make_current == nullptr) return EGL_FALSE;
  return g_real_make_current(display, draw, read, context);
}

void note_gtk_thread() {
  g_gtk_thread = pthread_self();
  g_gtk_thread_known = true;
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
  install_damage_gate();
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
  note_gtk_thread();
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

// gdk_window_create_gl_context stores the paint GL context on the native
// window. begin_paint then calls eglMakeCurrent and uploads a full-window
// texture on this thread. mpv still needs that context object, so the
// pointer is only unhooked while the window is unfocused. Exposes then take
// the cairo path, and the attach is dropped.
GdkGLContext** g_paint_slot = nullptr;
GdkGLContext* g_paint_context = nullptr;
bool g_paint_hidden = false;
bool g_logged_paint_slot = false;

GdkGLContext** find_paint_slot(GdkWindow* window, GdkGLContext* paint) {
  if (window == nullptr || paint == nullptr) return nullptr;
  GTypeQuery query{};
  g_type_query(G_OBJECT_TYPE(window), &query);
  if (query.instance_size < sizeof(void*)) return nullptr;
  auto* base = reinterpret_cast<char*>(window);
  for (guint offset = 0; offset + sizeof(void*) <= query.instance_size;
       offset += sizeof(void*)) {
    auto* slot = reinterpret_cast<GdkGLContext**>(base + offset);
    if (*slot == paint) return slot;
  }
  return nullptr;
}

void remember_paint_context(GdkWindow* window, GdkGLContext* created) {
  if (g_paint_slot != nullptr || window == nullptr || created == nullptr) {
    return;
  }
  GdkGLContext* paint = gdk_gl_context_get_shared_context(created);
  if (paint == nullptr) return;
  GdkWindow* cursor = window;
  for (int i = 0; i < 8 && cursor != nullptr; i++) {
    GdkGLContext** slot = find_paint_slot(cursor, paint);
    if (slot != nullptr) {
      g_paint_slot = slot;
      g_paint_context = paint;
      g_object_ref(paint);
      if (!g_logged_paint_slot) {
        g_logged_paint_slot = true;
        g_message("present: window paint gl context is detachable");
      }
      return;
    }
    GdkWindow* toplevel = gdk_window_get_toplevel(cursor);
    if (toplevel == cursor) break;
    cursor = gdk_window_get_parent(cursor);
  }
  if (!g_logged_paint_slot) {
    g_logged_paint_slot = true;
    g_message("present: window paint gl context was not found on the window");
  }
}

void hide_paint_context() {
  if (g_paint_slot == nullptr || g_paint_context == nullptr) return;
  if (*g_paint_slot != g_paint_context) return;
  *g_paint_slot = nullptr;
  g_paint_hidden = true;
  g_message("present: hid the window paint gl context while unfocused");
}

void show_paint_context() {
  if (!g_paint_hidden || g_paint_slot == nullptr || g_paint_context == nullptr) {
    return;
  }
  if (*g_paint_slot == nullptr) *g_paint_slot = g_paint_context;
  g_paint_hidden = false;
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
    hide_paint_context();
    g_hold_expose.store(true, std::memory_order_release);
  } else {
    show_paint_context();
    if (g_renderer != nullptr && g_original_draw != nullptr) {
      // Schedule the frame the expose would have scheduled. Calling the
      // renderer draw from here does not enter GDK begin_paint, so it does
      // not attach the white buffer. The onscreen draw only schedules.
      g_original_draw(g_renderer, nullptr);
      g_message("present: scheduled frame without a GTK paint");
    }
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

// media_kit calls this and GDK stores the paint context on the window as a
// side effect. Remember that slot so an unfocused expose can avoid it.
extern "C" GdkGLContext* gdk_window_create_gl_context(GdkWindow* window,
                                                     GError** error) {
  using CreateFn = GdkGLContext* (*)(GdkWindow*, GError**);
  static CreateFn real = nullptr;
  if (real == nullptr) {
    real = reinterpret_cast<CreateFn>(
        dlsym(RTLD_NEXT, "gdk_window_create_gl_context"));
  }
  if (real == nullptr) return nullptr;
  GdkGLContext* created = real(window, error);
  remember_paint_context(window, created);
  if (!g_present_allowed.load(std::memory_order_acquire)) hide_paint_context();
  return created;
}

// libgtk calls this around every expose. Detach the paint context before
// GDK reads it, or begin_paint makes a second EGL context current.
extern "C" GdkDrawingContext* gdk_window_begin_draw_frame(
    GdkWindow* window, const cairo_region_t* region) {
  using BeginFn = GdkDrawingContext* (*)(GdkWindow*, const cairo_region_t*);
  static BeginFn real = nullptr;
  if (real == nullptr) {
    real = reinterpret_cast<BeginFn>(
        dlsym(RTLD_NEXT, "gdk_window_begin_draw_frame"));
  }
  if (!g_present_allowed.load(std::memory_order_acquire)) hide_paint_context();
  if (real == nullptr) return nullptr;
  return real(window, region);
}

// GDK calls libEGL's eglSwapBuffers from gdk_window_end_draw_frame. The
// epoxy pointer gate does not see that call. The first unfocus of a process
// can already be inside that paint; hybris then blocks in finishSwap and
// the wayland client heap aborts. This definition is what libgdk binds.
extern "C" EGLBoolean eglSwapBuffers(EGLDisplay display, EGLSurface surface) {
  return gastube_gated_egl_swap(display, surface);
}

// GDK resizes the hybris window from the configure event while a present may
// still own the previous buffer. The same lock as both swap entry points
// keeps the cancel from freeing that buffer mid-swap. A resize that arrives
// on this thread during the swap is applied after the swap returns.
struct wl_egl_window;
extern "C" void wl_egl_window_resize(struct wl_egl_window* window, int width,
                                    int height, int dx, int dy) {
  if (g_real_wl_resize == nullptr) {
    g_real_wl_resize =
        reinterpret_cast<WlEglResizeFn>(dlsym(RTLD_NEXT, "wl_egl_window_resize"));
  }
  if (g_real_wl_resize == nullptr) return;
  lock_hybris_window();
  if (g_hybris_depth > 1 || g_applying_resize) {
    g_resize_pending = true;
    g_resize_window = window;
    g_resize_w = width;
    g_resize_h = height;
    g_resize_dx = dx;
    g_resize_dy = dy;
  } else {
    g_real_wl_resize(window, width, height, dx, dy);
  }
  unlock_hybris_window();
}

extern "C" int wl_display_flush(struct wl_display* display) {
  // Surface attach and commit are already dropped. This flush still has to
  // run: it carries the Wayland ping reply. Holding it while the file
  // manager is open makes the compositor drop the client, and the last
  // frame stays on screen with input dead.
  if (!g_present_allowed.load(std::memory_order_acquire)) {
    bool already = g_logged_flush.exchange(true, std::memory_order_relaxed);
    if (!already) {
      g_message("present: flushed wayland while the window is unfocused");
    }
  }
  using FlushFn = int (*)(struct wl_display*);
  static FlushFn real = nullptr;
  if (real == nullptr) {
    real = reinterpret_cast<FlushFn>(dlsym(RTLD_NEXT, "wl_display_flush"));
  }
  if (real == nullptr) return -1;
  return real(display);
}

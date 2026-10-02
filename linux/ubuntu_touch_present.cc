#include <gdk/gdk.h>
#include <gtk/gtk.h>

#include <dlfcn.h>

#include <algorithm>
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

gboolean timed_draw(GtkWidget* widget, cairo_t* cr) {
  gint64 start = g_get_monotonic_time();
  gboolean result = FALSE;
  if (g_original_draw != nullptr) result = g_original_draw(widget, cr);
  gint64 now = g_get_monotonic_time();
  note_draw(now - start, now);
  return result;
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
  GtkWidget* renderer = nullptr;
  find_renderer(view, &renderer);
  if (renderer != nullptr && g_original_draw == nullptr) {
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

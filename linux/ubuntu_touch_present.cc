#include <gtk/gtk.h>

#include <dlfcn.h>

#include <cstdint>
#include <cstring>
#include <mutex>

// Ubuntu Touch on the OnePlus 6T. GTK 3.24 only reuses the previous frame when
// it sees EGL_EXT_buffer_age. This device does not advertise that string, but
// EGL_KHR_partial_update defines the same query token (0x313D). Without the
// string, gdk_wayland_window_invalidate_for_new_frame expands every update to
// the whole window. epoxy_has_egl_extension is a real function and can be
// wrapped. epoxy_eglQuerySurface is a function pointer in libepoxy; defining
// it as a function makes GTK jump to the first bytes of that function.
//
// The official libflutter_linux_gtk.so reports the whole layer as its paint
// region. A partial invalidate is used only after the Ubuntu Touch engine
// fills paint_region with the dirty rects. GTK still expands the region when
// the buffer age is 0, so a destroyed back buffer is painted in full.

namespace {

constexpr int kAlign = 32;

using HasExtensionFn = bool (*)(void*, const char*);
using QueueDrawFn = void (*)(GtkWidget*);
using QueueRegionFn = void (*)(GtkWidget*, cairo_region_t*);
using PresentFn = void (*)(void*, const void* const*, size_t);

struct PresentInfo {
  size_t struct_size;
  void* paint_region;
};

struct Region {
  size_t struct_size;
  size_t rects_count;
  void* rects;
};

struct Rect {
  double left;
  double top;
  double right;
  double bottom;
};

struct Layer {
  size_t struct_size;
  int type;
  int pad;
  const void* content;
  double offset_x;
  double offset_y;
  double width;
  double height;
  const PresentInfo* present_info;
  int64_t presentation_time;
};

template <typename T>
T load_next(const char* name) {
  return reinterpret_cast<T>(dlsym(RTLD_NEXT, name));
}

std::mutex g_damage_mu;
cairo_region_t* g_damage = nullptr;
int g_frame_w = 0;
int g_frame_h = 0;
bool g_damage_partial = false;
bool g_logged_partial = false;
PresentFn g_original_present = nullptr;

bool is_renderer(GtkWidget* widget) {
  return widget != nullptr &&
         g_strcmp0(G_OBJECT_TYPE_NAME(widget), "FlViewRenderer") == 0;
}

void store_full() {
  std::lock_guard<std::mutex> lock(g_damage_mu);
  g_damage_partial = false;
  g_frame_w = 0;
  g_frame_h = 0;
  if (g_damage != nullptr) {
    cairo_region_destroy(g_damage);
    g_damage = nullptr;
  }
}

void store_region(cairo_region_t* region, int frame_w, int frame_h) {
  std::lock_guard<std::mutex> lock(g_damage_mu);
  if (g_damage != nullptr) cairo_region_destroy(g_damage);
  g_damage = region;
  g_frame_w = frame_w;
  g_frame_h = frame_h;
  g_damage_partial = region != nullptr;
}

cairo_region_t* copy_damage(int* frame_w, int* frame_h) {
  std::lock_guard<std::mutex> lock(g_damage_mu);
  if (!g_damage_partial || g_damage == nullptr) {
    return nullptr;
  }
  *frame_w = g_frame_w;
  *frame_h = g_frame_h;
  return cairo_region_copy(g_damage);
}

int align_down(int value) {
  if (value < 0) return 0;
  return value & ~(kAlign - 1);
}

int align_up(int value, int limit) {
  int aligned = (value + kAlign - 1) & ~(kAlign - 1);
  if (aligned > limit) aligned = limit;
  return aligned;
}

void present_layers(void* renderable, const void* const* layers,
                    size_t layers_count) {
  bool partial = layers_count > 0;
  int frame_w = 0;
  int frame_h = 0;
  cairo_region_t* region = cairo_region_create();

  for (size_t i = 0; i < layers_count; i++) {
    auto* layer = reinterpret_cast<const Layer*>(layers[i]);
    if (layer == nullptr || layer->struct_size < sizeof(Layer) ||
        layer->type != 0 || layer->width < 1 || layer->height < 1) {
      partial = false;
      break;
    }
    frame_w = static_cast<int>(layer->width);
    frame_h = static_cast<int>(layer->height);
    const PresentInfo* info = layer->present_info;
    if (info == nullptr || info->struct_size < sizeof(PresentInfo) ||
        info->paint_region == nullptr) {
      partial = false;
      break;
    }
    auto* paint = reinterpret_cast<const Region*>(info->paint_region);
    if (paint->struct_size < sizeof(Region) || paint->rects == nullptr) {
      partial = false;
      break;
    }
    auto* rects = reinterpret_cast<const Rect*>(paint->rects);
    for (size_t r = 0; r < paint->rects_count; r++) {
      int x0 = align_down(static_cast<int>(rects[r].left));
      int y0 = align_down(static_cast<int>(rects[r].top));
      int x1 = align_up(static_cast<int>(rects[r].right + 0.999), frame_w);
      int y1 = align_up(static_cast<int>(rects[r].bottom + 0.999), frame_h);
      if (x1 <= x0 || y1 <= y0) continue;
      cairo_rectangle_int_t rect{x0, y0, x1 - x0, y1 - y0};
      cairo_region_union_rectangle(region, &rect);
    }
  }

  cairo_rectangle_int_t bounds;
  cairo_region_get_extents(region, &bounds);
  bool covers_frame = bounds.width >= frame_w && bounds.height >= frame_h;
  if (!partial || frame_w < 1 || frame_h < 1 ||
      cairo_region_is_empty(region) || covers_frame) {
    cairo_region_destroy(region);
    store_full();
  } else {
    store_region(region, frame_w, frame_h);
  }

  if (g_original_present != nullptr) {
    g_original_present(renderable, layers, layers_count);
  }
}

struct RenderableIface {
  GTypeInterface parent;
  PresentFn present_layers;
};

}  // namespace

void gastube_ut_install_present_hook(GtkWidget* view) {
  GType type = g_type_from_name("FlRenderable");
  if (type == 0 || view == nullptr) {
    g_warning("present hook: FlRenderable is not registered");
    return;
  }
  auto* iface = reinterpret_cast<RenderableIface*>(
      g_type_interface_peek(G_OBJECT_GET_CLASS(view), type));
  if (iface == nullptr || iface->present_layers == nullptr) {
    g_warning("present hook: FlView does not implement FlRenderable");
    return;
  }
  if (iface->present_layers == present_layers) return;
  g_original_present = iface->present_layers;
  iface->present_layers = present_layers;
  g_message("present hook: paint_region will invalidate the Flutter view");
}

extern "C" bool epoxy_has_egl_extension(void* dpy, const char* extension) {
  static HasExtensionFn real = load_next<HasExtensionFn>("epoxy_has_egl_extension");
  if (real == nullptr) return false;
  if (extension != nullptr &&
      std::strcmp(extension, "EGL_EXT_buffer_age") == 0 &&
      real(dpy, "EGL_KHR_partial_update")) {
    return true;
  }
  return real(dpy, extension);
}

extern "C" void gtk_widget_queue_draw(GtkWidget* widget) {
  static QueueDrawFn real = load_next<QueueDrawFn>("gtk_widget_queue_draw");
  static thread_local int in_queue = 0;
  if (in_queue > 0) {
    real(widget);
    return;
  }
  in_queue++;
  int frame_w = 0;
  int frame_h = 0;
  cairo_region_t* damage = nullptr;
  if (is_renderer(widget)) damage = copy_damage(&frame_w, &frame_h);
  if (damage == nullptr || frame_w < 1 || frame_h < 1) {
    if (damage != nullptr) cairo_region_destroy(damage);
    real(widget);
    in_queue--;
    return;
  }

  GtkAllocation allocation;
  gtk_widget_get_allocation(widget, &allocation);
  if (allocation.width < 1 || allocation.height < 1) {
    cairo_region_destroy(damage);
    real(widget);
    in_queue--;
    return;
  }

  cairo_region_t* widget_region = cairo_region_create();
  int count = cairo_region_num_rectangles(damage);
  for (int i = 0; i < count; i++) {
    cairo_rectangle_int_t rect;
    cairo_region_get_rectangle(damage, i, &rect);
    int x0 = rect.x * allocation.width / frame_w;
    int y0 = rect.y * allocation.height / frame_h;
    int x1 = (rect.x + rect.width) * allocation.width / frame_w;
    int y1 = (rect.y + rect.height) * allocation.height / frame_h;
    if (x1 <= x0 || y1 <= y0) continue;
    cairo_rectangle_int_t mapped{x0, y0, x1 - x0, y1 - y0};
    cairo_region_union_rectangle(widget_region, &mapped);
  }
  cairo_region_destroy(damage);

  cairo_rectangle_int_t extents;
  cairo_region_get_extents(widget_region, &extents);
  if (cairo_region_is_empty(widget_region) ||
      (extents.width >= allocation.width &&
       extents.height >= allocation.height)) {
    cairo_region_destroy(widget_region);
    real(widget);
    in_queue--;
    return;
  }

  if (!g_logged_partial) {
    g_logged_partial = true;
    g_message("gastube: partial present %dx%d of %dx%d",
              extents.width, extents.height, allocation.width,
              allocation.height);
  }
  static QueueRegionFn queue_region =
      load_next<QueueRegionFn>("gtk_widget_queue_draw_region");
  queue_region(widget, widget_region);
  cairo_region_destroy(widget_region);
  in_queue--;
}

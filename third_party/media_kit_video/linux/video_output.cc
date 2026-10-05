// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output.h"
#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/texture_sw.h"

#include <epoxy/egl.h>
#include <epoxy/gl.h>
#include <epoxy/glx.h>
#include <gdk/gdkwayland.h>
#include <gdk/gdkx.h>

struct _VideoOutput {
  GObject parent_instance;
  TextureGL* texture_gl;
  GdkGLContext* gdk_gl_context;
  guint8* pixel_buffer;
  TextureSW* texture_sw;
  GMutex mutex; /* Only used in S/W rendering. */
  mpv_handle* handle;
  mpv_render_context* render_context;
  gint64 width;
  gint64 height;
  VideoOutputConfiguration configuration;
  TextureUpdateCallback texture_update_callback;
  gpointer texture_update_callback_context;
  FlTextureRegistrar* texture_registrar;
  gboolean destroyed;
  gboolean flutter_gl_bound;
  gint texture_epoch;
  gint rebind_wait;
};

G_DEFINE_TYPE(VideoOutput, video_output, G_TYPE_OBJECT)

static void video_output_dispose(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);
  self->destroyed = TRUE;
  // H/W
  if (self->texture_gl) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_gl));
    if (self->gdk_gl_context) {
      g_object_unref(self->gdk_gl_context);
    }
    g_object_unref(self->texture_gl);
  }
  // S/W
  if (self->texture_sw) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    g_free(self->pixel_buffer);
    g_object_unref(self->texture_sw);
  }
  if (self->render_context) {
    mpv_render_context_free(self->render_context);
  }
  g_mutex_clear(&self->mutex);
  g_print("media_kit: VideoOutput: video_output_dispose: %ld\n",
          (gint64)self->handle);
  G_OBJECT_CLASS(video_output_parent_class)->dispose(object);
}

static void video_output_class_init(VideoOutputClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_dispose;
}

static void video_output_init(VideoOutput* self) {
  self->texture_gl = NULL;
  self->gdk_gl_context = NULL;
  self->texture_sw = NULL;
  self->pixel_buffer = NULL;
  self->handle = NULL;
  self->render_context = NULL;
  self->width = 0;
  self->height = 0;
  self->configuration = VideoOutputConfiguration{};
  self->texture_update_callback = NULL;
  self->texture_update_callback_context = NULL;
  self->texture_registrar = NULL;
  self->destroyed = FALSE;
  self->flutter_gl_bound = FALSE;
  self->texture_epoch = 0;
  self->rebind_wait = 0;
  g_mutex_init(&self->mutex);
}

static void request_flutter_gl_context(VideoOutput* self);

VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              FlView* view,
                              gint64 handle,
                              VideoOutputConfiguration configuration) {
  g_print("media_kit: VideoOutput: video_output_new: %ld\n", handle);
  VideoOutput* self = VIDEO_OUTPUT(g_object_new(video_output_get_type(), NULL));
  self->texture_registrar = texture_registrar;
  self->handle = (mpv_handle*)handle;
  self->width = configuration.width;
  self->height = configuration.height;
  self->configuration = configuration;
#ifndef MPV_RENDER_API_TYPE_SW
  // MPV_RENDER_API_TYPE_SW must be available for S/W rendering.
  if (!self->configuration.enable_hardware_acceleration) {
    g_printerr("media_kit: VideoOutput: S/W rendering is not supported.\n");
  }
  self->configuration.enable_hardware_acceleration = TRUE;
#endif
  mpv_set_option_string(self->handle, "video-sync", "audio");
  mpv_set_option_string(self->handle, "video-timing-offset", "0");
  gboolean hardware_acceleration_supported = FALSE;
  if (self->configuration.enable_hardware_acceleration) {
    GError* error = NULL;
    GdkWindow* window = gtk_widget_get_window(GTK_WIDGET(view));
    self->gdk_gl_context = gdk_window_create_gl_context(window, &error);
    if (error == NULL) {
      // This context only bootstraps mpv frame callbacks. It is desktop GL.
      // The first FlTextureGL populate rebinds mpv onto Flutter's GLES context.
      gdk_gl_context_realize(self->gdk_gl_context, &error);
      if (error == NULL) {
        gdk_gl_context_make_current(self->gdk_gl_context);
        const char* gl_vendor = (const char*)glGetString(GL_VENDOR);
        g_print(
            "media_kit: GL context GDK: vendor=%s renderer=%s version=%s\n",
            gl_vendor, (const char*)glGetString(GL_RENDERER),
            (const char*)glGetString(GL_VERSION));
        // An empty vendor means this context cannot feed mpv. Keep the GL
        // texture and create the render context later on Flutter's context.
        // The software pixel path copies a full RGB frame on the UI thread.
        const bool gdk_gl_usable = gl_vendor != nullptr && gl_vendor[0] != '\0';
        if (!gdk_gl_usable) {
          g_print(
              "media_kit: VideoOutput: GDK GL context is empty, using Flutter "
              "GL context\n");
        }
        self->texture_gl = texture_gl_new(self);
        if (fl_texture_registrar_register_texture(
                texture_registrar, FL_TEXTURE(self->texture_gl))) {
          if (!gdk_gl_usable) {
            hardware_acceleration_supported = TRUE;
            request_flutter_gl_context(self);
          } else {
          mpv_opengl_init_params gl_init_params{
              [](auto, auto name) {
                GdkDisplay* display = gdk_display_get_default();
                if (GDK_IS_WAYLAND_DISPLAY(display)) {
                  return (void*)eglGetProcAddress(name);
                }
                if (GDK_IS_X11_DISPLAY(display)) {
                  return (void*)glXGetProcAddressARB((const GLubyte*)name);
                }
                g_assert_not_reached();
                return (void*)NULL;
              },
              NULL,
          };
          mpv_render_param params[] = {
              {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_OPENGL},
              {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, (void*)&gl_init_params},
              {MPV_RENDER_PARAM_INVALID, (void*)0},
              {MPV_RENDER_PARAM_INVALID, (void*)0},
          };
          GdkDisplay* display = gdk_display_get_default();
          if (GDK_IS_WAYLAND_DISPLAY(display)) {
            params[2].type = MPV_RENDER_PARAM_WL_DISPLAY;
            params[2].data = gdk_wayland_display_get_wl_display(display);
          } else if (GDK_IS_X11_DISPLAY(display)) {
            params[2].type = MPV_RENDER_PARAM_X11_DISPLAY;
            params[2].data = gdk_x11_display_get_xdisplay(display);
          }
          if (mpv_render_context_create(&self->render_context, self->handle,
                                        params) == 0) {
            mpv_render_context_set_update_callback(
                self->render_context,
                [](void* data) {
                  VideoOutput* output = (VideoOutput*)data;
                  if (output->destroyed) {
                    return;
                  }
                  fl_texture_registrar_mark_texture_frame_available(
                      output->texture_registrar, FL_TEXTURE(output->texture_gl));
                },
                self);
            hardware_acceleration_supported = TRUE;
            g_print("media_kit: VideoOutput: Using H/W rendering.\n");
          } else {
            g_print(
                "media_kit: VideoOutput: GDK mpv context failed, using "
                "Flutter GL context\n");
            self->render_context = NULL;
            hardware_acceleration_supported = TRUE;
            request_flutter_gl_context(self);
          }
          }
        }
      }
    }
    if (error) {
      g_print("media_kit: VideoOutput: GError: %d\n", error->code);
      g_print("media_kit: VideoOutput: GError: %s\n", error->message);
    }
  }
#ifdef MPV_RENDER_API_TYPE_SW
  if (!hardware_acceleration_supported) {
    // H/W rendering failed somewhere down the line. Fallback to S/W
    // rendering.
    self->pixel_buffer = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
    self->texture_gl = NULL;
    self->gdk_gl_context = NULL;
    self->texture_sw = texture_sw_new(self);
    if (fl_texture_registrar_register_texture(texture_registrar,
                                              FL_TEXTURE(self->texture_sw))) {
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, (void*)0},
      };
      if (mpv_render_context_create(&self->render_context, self->handle,
                                    params) == 0) {
        mpv_render_context_set_update_callback(
            self->render_context,
            [](void* data) {
              // Usage on single-thread is not a concern with pixel buffers
              // unlike OpenGL. So, I'd like to render on a separate thread
              // for slowing the UI thread as little as possible. It's a pity
              // that software rendering is feeling faster than hardware
              // rendering due to fucked-up GTK.
              gdk_threads_add_idle(
                  [](gpointer data) -> gboolean {
                    VideoOutput* self = (VideoOutput*)data;
                    if (self->destroyed) {
                      return FALSE;
                    }
                    g_mutex_lock(&self->mutex);
                    gint64 width = video_output_get_width(self);
                    gint64 height = video_output_get_height(self);
                    if (width > 0 && height > 0) {
                      gint32 size[]{(gint32)width, (gint32)height};
                      gint32 pitch = 4 * (gint32)width;
                      mpv_render_param params[]{
                          {MPV_RENDER_PARAM_SW_SIZE, size},
                          {MPV_RENDER_PARAM_SW_FORMAT, (void*)"rgb0"},
                          {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
                          {MPV_RENDER_PARAM_SW_POINTER, self->pixel_buffer},
                          {MPV_RENDER_PARAM_INVALID, (void*)0},
                      };
                      mpv_render_context_render(self->render_context, params);
                      fl_texture_registrar_mark_texture_frame_available(
                          self->texture_registrar,
                          FL_TEXTURE(self->texture_sw));
                    }
                    g_mutex_unlock(&self->mutex);
                    return FALSE;
                  },
                  data);
            },
            self);
        g_print("media_kit: VideoOutput: Using S/W rendering.\n");
      }
    }
  }
#endif
  return self;
}

gboolean video_output_ensure_render_context(VideoOutput* self) {
  if (self->flutter_gl_bound) {
    return self->render_context != NULL;
  }
  if (self->texture_gl == NULL || self->destroyed) {
    return FALSE;
  }
  if (self->render_context != NULL) {
    mpv_render_context_free(self->render_context);
    self->render_context = NULL;
  }
  mpv_opengl_init_params gl_init_params{
      [](auto, auto name) { return (void*)eglGetProcAddress(name); },
      NULL,
  };
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_OPENGL},
      {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, (void*)&gl_init_params},
      {MPV_RENDER_PARAM_INVALID, (void*)0},
      {MPV_RENDER_PARAM_INVALID, (void*)0},
  };
  GdkDisplay* display = gdk_display_get_default();
  if (GDK_IS_WAYLAND_DISPLAY(display)) {
    params[2].type = MPV_RENDER_PARAM_WL_DISPLAY;
    params[2].data = gdk_wayland_display_get_wl_display(display);
  } else if (GDK_IS_X11_DISPLAY(display)) {
    params[2].type = MPV_RENDER_PARAM_X11_DISPLAY;
    params[2].data = gdk_x11_display_get_xdisplay(display);
  }
  if (mpv_render_context_create(&self->render_context, self->handle, params) !=
      0) {
    g_print(
        "media_kit: VideoOutput: mpv_render_context_create failed on Flutter "
        "GL context\n");
    self->render_context = NULL;
    return FALSE;
  }
  mpv_render_context_set_update_callback(
      self->render_context,
      [](void* data) {
        VideoOutput* output = (VideoOutput*)data;
        if (output->destroyed || output->texture_gl == NULL) {
          return;
        }
        // The first frame after the track is selected again must be imported
        // under a new GL name. Impeller keeps the name from the empty draw.
        if (g_atomic_int_compare_and_exchange(&output->rebind_wait, 1, 0)) {
          g_atomic_int_inc(&output->texture_epoch);
        }
        fl_texture_registrar_mark_texture_frame_available(
            output->texture_registrar, FL_TEXTURE(output->texture_gl));
      },
      self);
  g_print(
      "media_kit: VideoOutput: mpv render context created on Flutter GL "
      "context\n");
  self->flutter_gl_bound = TRUE;
  // Freeing the GDK render context calls kill_video_async() in libmpv 0.35.
  // That deselects the video track and leaves audio running, which is why the
  // first file has sound and a black picture until the next open() selects
  // video again. vid is already "auto", so set it to "no" and back. The next
  // frame then allocates a new GL texture. Impeller keeps the name from the
  // empty draw that happened before this. Runs on the GTK thread because
  // populate is on the raster thread and must not wait on mpv.
  g_idle_add(
      [](gpointer data) -> gboolean {
        VideoOutput* output = (VideoOutput*)data;
        if (!output->destroyed) {
          int disabled = mpv_set_property_string(output->handle, "vid", "no");
          int restored = mpv_set_property_string(output->handle, "vid", "auto");
          // Arm after the property changes. The next frame callback, not this
          // empty draw, allocates the texture Impeller will keep.
          g_atomic_int_set(&output->rebind_wait, 1);
          g_print(
              "media_kit: VideoOutput: video track reselected after context "
              "replace (%d, %d)\n",
              disabled, restored);
        }
        g_object_unref(output);
        return G_SOURCE_REMOVE;
      },
      g_object_ref(self));
  return TRUE;
}

gint video_output_texture_epoch(VideoOutput* self) {
  return g_atomic_int_get(&self->texture_epoch);
}

void video_output_request_frame(VideoOutput* self) {
  if (self->destroyed || self->texture_gl == NULL) {
    return;
  }
  fl_texture_registrar_mark_texture_frame_available(
      self->texture_registrar, FL_TEXTURE(self->texture_gl));
}

void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context) {
  self->texture_update_callback = texture_update_callback;
  self->texture_update_callback_context = texture_update_callback_context;
  // Notify initial dimensions as (1, 1) if |width| & |height| are 0 i.e.
  // texture & video frame size is based on playing file's resolution. This
  // will make sure that `Texture` widget on Flutter's widget tree is actually
  // mounted & |fl_texture_registrar_mark_texture_frame_available| actually
  // invokes the |TextureGL| or |TextureSW| callbacks. Otherwise it will be a
  // never ending deadlock where no video frames are ever rendered.
  gint64 texture_id = video_output_get_texture_id(self);
  if (self->width == 0 || self->height == 0) {
    self->texture_update_callback(texture_id, 1, 1,
                                  self->texture_update_callback_context);
  } else {
    self->texture_update_callback(texture_id, self->width, self->height,
                                  self->texture_update_callback_context);
  }
}

static void request_flutter_gl_context(VideoOutput* self) {
  if (self->destroyed || self->texture_gl == NULL || self->flutter_gl_bound) {
    return;
  }
  struct Kick {
    VideoOutput* output;
    int tries;
  };
  Kick* kick = g_new0(Kick, 1);
  kick->output = VIDEO_OUTPUT(g_object_ref(self));
  g_timeout_add(
      50,
      [](gpointer data) -> gboolean {
        Kick* kick = static_cast<Kick*>(data);
        VideoOutput* output = kick->output;
        if (output->destroyed || output->texture_gl == NULL ||
            output->flutter_gl_bound || kick->tries >= 20) {
          g_object_unref(output);
          g_free(kick);
          return G_SOURCE_REMOVE;
        }
        fl_texture_registrar_mark_texture_frame_available(
            output->texture_registrar, FL_TEXTURE(output->texture_gl));
        if (kick->tries == 0) {
          g_print("media_kit: VideoOutput: requested Flutter GL context\n");
        }
        kick->tries += 1;
        return G_SOURCE_CONTINUE;
      },
      kick);
}

void video_output_set_size(VideoOutput* self, gint64 width, gint64 height) {
  // Ideally, a mutex should be used here & |video_output_get_width| +
  // |video_output_get_height|. However, that is throwing everything into a
  // deadlock. Flutter itself seems to have some synchronization mechanism in
  // rendering & platform channels AFAIK.

  // H/W
  if (self->texture_gl) {
    self->width = width;
    self->height = height;
    request_flutter_gl_context(self);
  }
  // S/W
  if (self->texture_sw) {
    self->width = CLAMP(width, 0, SW_RENDERING_MAX_WIDTH);
    self->height = CLAMP(height, 0, SW_RENDERING_MAX_HEIGHT);
  }
}

mpv_render_context* video_output_get_render_context(VideoOutput* self) {
  return self->render_context;
}

GdkGLContext* video_output_get_gdk_gl_context(VideoOutput* self) {
  return self->gdk_gl_context;
}

guint8* video_output_get_pixel_buffer(VideoOutput* self) {
  return self->pixel_buffer;
}

gint64 video_output_get_width(VideoOutput* self) {
  // Fixed width.
  if (self->width) {
    return self->width;
  }

  // Video resolution dependent width.
  gint64 width = 0;
  gint64 height = 0;

  mpv_node params;
  mpv_get_property(self->handle, "video-out-params", MPV_FORMAT_NODE, &params);

  int64_t dw = 0, dh = 0, rotate = 0;
  if (params.format == MPV_FORMAT_NODE_MAP) {
    for (int32_t i = 0; i < params.u.list->num; i++) {
      char* key = params.u.list->keys[i];
      auto value = params.u.list->values[i];
      if (value.format == MPV_FORMAT_INT64) {
        if (strcmp(key, "dw") == 0) {
          dw = value.u.int64;
        }
        if (strcmp(key, "dh") == 0) {
          dh = value.u.int64;
        }
        if (strcmp(key, "rotate") == 0) {
          rotate = value.u.int64;
        }
      }
    }
    mpv_free_node_contents(&params);
  }

  width = rotate == 0 || rotate == 180 ? dw : dh;
  height = rotate == 0 || rotate == 180 ? dh : dw;

  if (self->texture_sw != NULL) {
    // Make sure |width| & |height| fit between |SW_RENDERING_MAX_WIDTH| &
    // |SW_RENDERING_MAX_HEIGHT| while maintaining aspect ratio.
    if (width >= SW_RENDERING_MAX_WIDTH) {
      return SW_RENDERING_MAX_WIDTH;
    }
    if (height >= SW_RENDERING_MAX_HEIGHT) {
      return width / height * SW_RENDERING_MAX_HEIGHT;
    }
  }

  return width;
}

gint64 video_output_get_height(VideoOutput* self) {
  // Fixed height.
  if (self->width) {
    return self->height;
  }

  // Video resolution dependent height.
  gint64 width = 0;
  gint64 height = 0;

  mpv_node params;
  mpv_get_property(self->handle, "video-out-params", MPV_FORMAT_NODE, &params);

  int64_t dw = 0, dh = 0, rotate = 0;
  if (params.format == MPV_FORMAT_NODE_MAP) {
    for (int32_t i = 0; i < params.u.list->num; i++) {
      char* key = params.u.list->keys[i];
      auto value = params.u.list->values[i];
      if (value.format == MPV_FORMAT_INT64) {
        if (strcmp(key, "dw") == 0) {
          dw = value.u.int64;
        }
        if (strcmp(key, "dh") == 0) {
          dh = value.u.int64;
        }
        if (strcmp(key, "rotate") == 0) {
          rotate = value.u.int64;
        }
      }
    }
    mpv_free_node_contents(&params);
  }

  width = rotate == 0 || rotate == 180 ? dw : dh;
  height = rotate == 0 || rotate == 180 ? dh : dw;

  if (self->texture_sw != NULL) {
    // Make sure |width| & |height| fit between |SW_RENDERING_MAX_WIDTH| &
    // |SW_RENDERING_MAX_HEIGHT| while maintaining aspect ratio.
    if (height >= SW_RENDERING_MAX_HEIGHT) {
      return SW_RENDERING_MAX_HEIGHT;
    }
    if (width >= SW_RENDERING_MAX_WIDTH) {
      return height / width * SW_RENDERING_MAX_WIDTH;
    }
  }

  return height;
}

gint64 video_output_get_texture_id(VideoOutput* self) {
  // H/W
  if (self->texture_gl) {
    return (gint64)self->texture_gl;
  }
  // S/W
  if (self->texture_sw) {
    return (gint64)self->texture_sw;
  }
  g_assert_not_reached();
  return -1;
}

void video_output_notify_texture_update(VideoOutput* self) {
  gint64 id = video_output_get_texture_id(self);
  gint64 width = video_output_get_width(self);
  gint64 height = video_output_get_height(self);
  gpointer context = self->texture_update_callback_context;
  if (self->texture_update_callback != NULL) {
    self->texture_update_callback(id, width, height, context);
  }
}

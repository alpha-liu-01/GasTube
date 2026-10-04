// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <epoxy/gl.h>

struct _TextureGL {
  FlTextureGL parent_instance;
  guint32 name;
  guint32 fbo;
  guint32 current_width;
  guint32 current_height;
  gboolean populating;
  gint seen_epoch;
  VideoOutput* video_output;
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

static void texture_gl_init(TextureGL* self) {
  self->name = 0;
  self->fbo = 0;
  self->current_width = 1;
  self->current_height = 1;
  self->populating = FALSE;
  self->seen_epoch = 0;
  self->video_output = NULL;
}

static void texture_gl_dispose(GObject* object) {
  TextureGL* self = TEXTURE_GL(object);
  // Free texture & FBO.
  if (self->name != 0) {
    glDeleteTextures(1, &self->name);
    self->name = 0;
  }
  if (self->fbo != 0) {
    glDeleteFramebuffers(1, &self->fbo);
    self->fbo = 0;
  }
  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
  G_OBJECT_CLASS(texture_gl_parent_class)->dispose(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->dispose = texture_gl_dispose;
}

TextureGL* texture_gl_new(VideoOutput* video_output) {
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* video_output = self->video_output;
  // mpv can invoke the frame callback from inside mpv_render_context_render.
  // That calls populate again. A second render on the same context corrupts
  // the heap; the UI thread then dies in malloc.
  if (self->populating) {
    *target = GL_TEXTURE_2D;
    *name = self->name;
    *width = self->current_width;
    *height = self->current_height;
    return TRUE;
  }
  self->populating = TRUE;
  static gboolean logged_flutter_context = FALSE;
  if (!logged_flutter_context) {
    logged_flutter_context = TRUE;
    g_print(
        "media_kit: GL context Flutter: vendor=%s renderer=%s version=%s\n",
        (const char*)glGetString(GL_VENDOR),
        (const char*)glGetString(GL_RENDERER),
        (const char*)glGetString(GL_VERSION));
  }
  gint32 required_width = (guint32)video_output_get_width(video_output);
  gint32 required_height = (guint32)video_output_get_height(video_output);
  gboolean need_another = FALSE;
  // An empty GDK context leaves mpv without a render context. Create it on
  // this thread, where Flutter's GLES context is current, before the first
  // frame has a size. Otherwise nothing ever marks the texture and playback
  // stays at 0:00.
  if (!video_output_ensure_render_context(video_output)) {
    self->populating = FALSE;
    g_print("media_kit: TextureGL: Flutter GL context not ready\n");
    return FALSE;
  }
  if (required_width > 0 && required_height > 0) {
    // The first texture name is imported while the draw is still empty.
    // Impeller keeps it. After the VO is moved onto this context, allocate
    // a new name so that import contains the picture.
    gint epoch = video_output_texture_epoch(video_output);
    if (epoch != self->seen_epoch && self->name != 0) {
      glDeleteTextures(1, &self->name);
      glDeleteFramebuffers(1, &self->fbo);
      self->name = 0;
      self->fbo = 0;
      g_print("media_kit: TextureGL: new texture after video output rebind\n");
    }
    gboolean first_frame = self->name == 0 || self->fbo == 0;
    if (first_frame) {
      g_print("media_kit: TextureGL: Resize: (%d, %d)\n", required_width,
              required_height);
      glGenFramebuffers(1, &self->fbo);
      glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
      glGenTextures(1, &self->name);
      glBindTexture(GL_TEXTURE_2D, self->name);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, required_width, required_height,
                   0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                             GL_TEXTURE_2D, self->name, 0);
      self->current_width = required_width;
      self->current_height = required_height;
      video_output_notify_texture_update(video_output);
    } else if (required_width != (gint32)self->current_width ||
               required_height != (gint32)self->current_height) {
      g_print("media_kit: TextureGL: Resize storage: (%d, %d)\n",
              required_width, required_height);
      glBindTexture(GL_TEXTURE_2D, self->name);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, required_width, required_height,
                   0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
      glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                             GL_TEXTURE_2D, self->name, 0);
      self->current_width = required_width;
      self->current_height = required_height;
      video_output_notify_texture_update(video_output);
    } else {
      glBindTexture(GL_TEXTURE_2D, self->name);
      glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
    }
    // Check while our FBO is bound. mpv unbinds it, and the default
    // framebuffer on Flutter's surfaceless GLES context is undefined
    // (0x8219), which is not a failed texture.
    GLenum fb_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (fb_status != GL_FRAMEBUFFER_COMPLETE) {
      g_print(
          "media_kit: TextureGL: framebuffer 0x%x, reallocating as RGBA8\n",
          fb_status);
      glBindTexture(GL_TEXTURE_2D, self->name);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, required_width, required_height,
                   0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
      glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                             GL_TEXTURE_2D, self->name, 0);
      fb_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
      g_print("media_kit: TextureGL: framebuffer after RGBA8: 0x%x\n",
              fb_status);
    }
    mpv_render_context* render_context =
        video_output_get_render_context(video_output);
    mpv_opengl_fbo fbo{(gint32)self->fbo, required_width, required_height, 0};
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
        {MPV_RENDER_PARAM_INVALID, NULL},
    };
    mpv_render_context_render(render_context, params);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    self->seen_epoch = epoch;
    need_another = video_output_texture_epoch(video_output) != epoch;
    glBindTexture(GL_TEXTURE_2D, 0);
    glFlush();
  }
  self->populating = FALSE;
  if (need_another) {
    video_output_request_frame(video_output);
  }
  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = self->current_width;
  *height = self->current_height;
  if (self->name == 0 && self->fbo == 0) {
    // This means that required_width > 0 && required_height > 0 code-path
    // hasn't been executed yet (because first frame isn't available yet).
    // Just creating a dummy texture & FBO; prevent Flutter from complaining.
    glGenFramebuffers(1, &self->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    *name = self->name;
    *width = 1;
    *height = 1;
  }
  return TRUE;
}

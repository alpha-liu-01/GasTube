/*
 * VP9 decoder that feeds raw frames to the phone's libhybris MediaCodec
 * and copies the output into a normal picture for libmpv.
 * The phone already has libmedia.so.1. This file is compiled into the
 * Ubuntu Touch FFmpeg build and is not used by desktop builds.
 * H.264 stays in h264_hybris.c. This decoder does not convert Annex-B.
 */

#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libavutil/frame.h"
#include "libavutil/internal.h"
#include "libavutil/mem.h"
#include "avcodec.h"
#include "codec_internal.h"

typedef void *HybrisCodec;
typedef void *HybrisFormat;

typedef struct HybrisBufferInfo {
    size_t index;
    size_t offset;
    size_t size;
    int64_t presentation_time_us;
    uint32_t flags;
    uint8_t render_retries;
} HybrisBufferInfo;

enum {
    HYBRIS_BUFFER_FLAG_SYNC = 1,
    HYBRIS_BUFFER_FLAG_EOS = 4,
    HYBRIS_TRY_AGAIN = -11,
    HYBRIS_FORMAT_CHANGED = -1012,
    HYBRIS_BUFFERS_CHANGED = -1013,
    HYBRIS_COLOR_YUV420_PLANAR = 19,
    HYBRIS_COLOR_YUV420_SEMIPLANAR = 21,
};

typedef struct HybrisApi {
    void (*init)(void);
    ssize_t (*find_codec)(const char *, bool, size_t);
    void (*codec_info)(size_t);
    const char *(*codec_name)(size_t);
    HybrisCodec (*create)(const char *);
    int (*configure)(HybrisCodec, HybrisFormat, void *, uint32_t);
    int (*queue_csd)(HybrisCodec, HybrisFormat);
    int (*start)(HybrisCodec);
    int (*flush)(HybrisCodec);
    int (*stop)(HybrisCodec);
    int (*release)(HybrisCodec);
    void (*destroy)(HybrisCodec);
    uint8_t *(*input_buffer)(HybrisCodec, size_t);
    size_t (*input_capacity)(HybrisCodec, size_t);
    uint8_t *(*output_buffer)(HybrisCodec, size_t);
    size_t (*output_capacity)(HybrisCodec, size_t);
    int (*dequeue_output)(HybrisCodec, HybrisBufferInfo *, int64_t);
    int (*queue_input)(HybrisCodec, const HybrisBufferInfo *);
    int (*dequeue_input)(HybrisCodec, size_t *, int64_t);
    int (*release_output)(HybrisCodec, size_t, uint8_t);
    HybrisFormat (*output_format)(HybrisCodec);
    HybrisFormat (*create_format)(const char *, int32_t, int32_t, int64_t, int32_t);
    void (*destroy_format)(HybrisFormat);
    void (*set_bytes)(HybrisFormat, const char *, uint8_t *, size_t);
    int32_t (*get_width)(HybrisFormat);
    int32_t (*get_height)(HybrisFormat);
    int32_t (*get_stride)(HybrisFormat);
    int32_t (*get_slice)(HybrisFormat);
    int32_t (*get_color)(HybrisFormat);
    int32_t (*get_crop_left)(HybrisFormat);
    int32_t (*get_crop_right)(HybrisFormat);
    int32_t (*get_crop_top)(HybrisFormat);
    int32_t (*get_crop_bottom)(HybrisFormat);
} HybrisApi;

typedef struct HybrisVp9Context {
    void *library;
    HybrisApi api;
    HybrisCodec codec;
    HybrisFormat format;
    const char *mime;
    uint8_t *csd0;
    int csd0_size;
    int started;
    int eos_queued;
    int need_sync;
    int dropped_sync;
    int drop_old;
    int64_t min_pts;
    int saw_format;
    int logged_color;
    int logged_buffer;
    int logged_picture;
    int logged_profile;
    AVFrame *held;
    int held_ready;
    int32_t out_width;
    int32_t out_height;
    int32_t stride;
    int32_t slice;
    int32_t color;
    int32_t crop_left;
    int32_t crop_top;
} HybrisVp9Context;

static void *sym(void *library, const char *name)
{
    void *fn = dlsym(library, name);
    if (!fn)
        fprintf(stderr, "gastube: mediacodec symbol missing: %s\n", name);
    return fn;
}

static int load_api(HybrisVp9Context *ctx)
{
    HybrisApi *api = &ctx->api;
    ctx->library = dlopen("libmedia.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (!ctx->library) {
        fprintf(stderr, "gastube: mediacodec dlopen failed: %s\n", dlerror());
        return AVERROR(ENOSYS);
    }
#define LOAD(field, name) do { \
        api->field = sym(ctx->library, name); \
        if (!api->field) \
            return AVERROR(ENOSYS); \
    } while (0)
    LOAD(init, "hybris_media_initialize");
    LOAD(find_codec, "media_codec_list_find_codec_by_type");
    LOAD(codec_info, "media_codec_list_get_codec_info_at_id");
    LOAD(codec_name, "media_codec_list_get_codec_name");
    LOAD(create, "media_codec_create_by_codec_name");
    LOAD(configure, "media_codec_configure");
    LOAD(queue_csd, "media_codec_queue_csd");
    LOAD(start, "media_codec_start");
    LOAD(flush, "media_codec_flush");
    LOAD(stop, "media_codec_stop");
    LOAD(release, "media_codec_release");
    LOAD(destroy, "media_codec_delegate_destroy");
    LOAD(input_buffer, "media_codec_get_nth_input_buffer");
    LOAD(input_capacity, "media_codec_get_nth_input_buffer_capacity");
    LOAD(output_buffer, "media_codec_get_nth_output_buffer");
    LOAD(output_capacity, "media_codec_get_nth_output_buffer_capacity");
    LOAD(dequeue_output, "media_codec_dequeue_output_buffer");
    LOAD(queue_input, "media_codec_queue_input_buffer");
    LOAD(dequeue_input, "media_codec_dequeue_input_buffer");
    LOAD(release_output, "media_codec_release_output_buffer");
    LOAD(output_format, "media_codec_get_output_format");
    LOAD(create_format, "media_format_create_video_format");
    LOAD(destroy_format, "media_format_destroy");
    LOAD(set_bytes, "media_format_set_byte_buffer");
    LOAD(get_width, "media_format_get_width");
    LOAD(get_height, "media_format_get_height");
    LOAD(get_stride, "media_format_get_stride");
    LOAD(get_slice, "media_format_get_slice_height");
    LOAD(get_color, "media_format_get_color_format");
    LOAD(get_crop_left, "media_format_get_crop_left");
    LOAD(get_crop_right, "media_format_get_crop_right");
    LOAD(get_crop_top, "media_format_get_crop_top");
    LOAD(get_crop_bottom, "media_format_get_crop_bottom");
#undef LOAD
    return 0;
}

static int find_qcom(HybrisVp9Context *ctx)
{
    static const char *mimes[] = { "video/x-vnd.on2.vp9", "video/vp9" };
    int mime_index;

    for (mime_index = 0; mime_index < 2; mime_index++) {
        size_t start = 0;
        int saw = 0;
        for (;;) {
            ssize_t index = ctx->api.find_codec(mimes[mime_index], false, start);
            const char *codec_name;
            if (index < 0 || (size_t)index < start) {
                if (!saw)
                    fprintf(stderr, "gastube: mediacodec %s index=%zd\n",
                            mimes[mime_index], index);
                break;
            }
            saw = 1;
            ctx->api.codec_info((size_t)index);
            codec_name = ctx->api.codec_name((size_t)index);
            fprintf(stderr, "gastube: mediacodec %s name=%s\n",
                    mimes[mime_index], codec_name ? codec_name : "(null)");
            if (codec_name && strstr(codec_name, "qcom")) {
                char chosen[128];
                snprintf(chosen, sizeof(chosen), "%s", codec_name);
                ctx->mime = mimes[mime_index];
                ctx->codec = ctx->api.create(chosen);
                if (!ctx->codec) {
                    fprintf(stderr, "gastube: mediacodec create failed\n");
                    return AVERROR_EXTERNAL;
                }
                fprintf(stderr, "gastube: mediacodec open name=%s mime=%s\n",
                        chosen, ctx->mime);
                return 0;
            }
            start = (size_t)index + 1;
        }
    }
    fprintf(stderr, "gastube: vp9-hw=absent\n");
    return AVERROR_DECODER_NOT_FOUND;
}

/* VP9 uncompressed header, MSB first: marker, profile low, profile high. */
static int vp9_profile(const uint8_t *data, int size)
{
    int low, high;
    if (size < 1 || ((data[0] >> 6) & 3) != 2)
        return -1;
    low = (data[0] >> 5) & 1;
    high = (data[0] >> 4) & 1;
    return (high << 1) | low;
}

static void read_output_format(HybrisVp9Context *ctx)
{
    HybrisFormat format = ctx->api.output_format(ctx->codec);
    int32_t right, bottom;

    if (!format)
        return;
    ctx->out_width = ctx->api.get_width(format);
    ctx->out_height = ctx->api.get_height(format);
    ctx->stride = ctx->api.get_stride(format);
    ctx->slice = ctx->api.get_slice(format);
    ctx->color = ctx->api.get_color(format);
    ctx->crop_left = ctx->api.get_crop_left(format);
    ctx->crop_top = ctx->api.get_crop_top(format);
    right = ctx->api.get_crop_right(format);
    bottom = ctx->api.get_crop_bottom(format);
    if (right > ctx->crop_left)
        ctx->out_width = right - ctx->crop_left + 1;
    if (bottom > ctx->crop_top)
        ctx->out_height = bottom - ctx->crop_top + 1;
    if (ctx->stride < ctx->out_width)
        ctx->stride = ctx->out_width;
    if (ctx->slice < ctx->out_height)
        ctx->slice = ctx->out_height;
    ctx->saw_format = 1;
    ctx->api.destroy_format(format);
    if (!ctx->logged_color) {
        ctx->logged_color = 1;
        fprintf(stderr,
                "gastube: mediacodec output color=%d stride=%d slice=%d %dx%d\n",
                ctx->color, ctx->stride, ctx->slice, ctx->out_width, ctx->out_height);
        if (ctx->color != HYBRIS_COLOR_YUV420_PLANAR &&
            ctx->color != HYBRIS_COLOR_YUV420_SEMIPLANAR)
            fprintf(stderr, "gastube: mediacodec vp9 color=%d\n", ctx->color);
    }
}

static int copy_plane(uint8_t *dst, int dst_stride, const uint8_t *src,
                      int src_stride, int width, int height, size_t capacity,
                      size_t origin)
{
    int row;
    for (row = 0; row < height; row++) {
        size_t at = origin + (size_t)row * (size_t)src_stride;
        if (at + (size_t)width > capacity)
            return AVERROR_INVALIDDATA;
        memcpy(dst + (size_t)row * (size_t)dst_stride, src + at, width);
    }
    return 0;
}

static int copy_output(HybrisVp9Context *ctx, AVFrame *frame,
                       const HybrisBufferInfo *info)
{
    /* data() already points at base + offset. */
    uint8_t *pixels = ctx->api.output_buffer(ctx->codec, info->index);
    size_t capacity = ctx->api.output_capacity(ctx->codec, info->index);
    size_t available = info->size > 0 ? info->size : capacity;
    int planar = ctx->color == HYBRIS_COLOR_YUV420_PLANAR;
    int ret;

    if (ctx->color != HYBRIS_COLOR_YUV420_PLANAR &&
        ctx->color != HYBRIS_COLOR_YUV420_SEMIPLANAR)
        return AVERROR_INVALIDDATA;
    if (!pixels || !ctx->saw_format || ctx->out_width <= 0 || ctx->out_height <= 0)
        return AVERROR(EAGAIN);
    if (!ctx->logged_buffer) {
        ctx->logged_buffer = 1;
        fprintf(stderr,
                "gastube: mediacodec buffer index=%zu offset=%zu size=%zu capacity=%zu y0=%02x ymid=%02x\n",
                info->index, info->offset, info->size, capacity,
                pixels[0], pixels[available / 2]);
    }
    frame->format = planar ? AV_PIX_FMT_YUV420P : AV_PIX_FMT_NV12;
    frame->width = ctx->out_width;
    frame->height = ctx->out_height;
    frame->color_range = AVCOL_RANGE_MPEG;
    frame->colorspace = ctx->out_height >= 720 ? AVCOL_SPC_BT709 : AVCOL_SPC_SMPTE170M;
    ret = av_frame_get_buffer(frame, 32);
    if (ret < 0)
        return ret;

    if (planar) {
        int chroma_stride = ctx->stride / 2;
        int chroma_h = ctx->out_height / 2;
        size_t y_at = (size_t)ctx->crop_top * (size_t)ctx->stride +
                      (size_t)ctx->crop_left;
        size_t chroma_at = (size_t)(ctx->crop_top / 2) * (size_t)chroma_stride +
                           (size_t)(ctx->crop_left / 2);
        size_t u_at = (size_t)ctx->stride * (size_t)ctx->slice + chroma_at;
        size_t v_at = u_at + (size_t)chroma_stride * (size_t)(ctx->slice / 2);
        ret = copy_plane(frame->data[0], frame->linesize[0], pixels, ctx->stride,
                         ctx->out_width, ctx->out_height, available, y_at);
        if (ret == 0)
            ret = copy_plane(frame->data[1], frame->linesize[1], pixels, chroma_stride,
                             ctx->out_width / 2, chroma_h, available, u_at);
        if (ret == 0)
            ret = copy_plane(frame->data[2], frame->linesize[2], pixels, chroma_stride,
                             ctx->out_width / 2, chroma_h, available, v_at);
    } else {
        size_t uv = (size_t)ctx->stride * (size_t)ctx->slice;
        ret = copy_plane(frame->data[0], frame->linesize[0], pixels, ctx->stride,
                         ctx->out_width, ctx->out_height, available,
                         (size_t)ctx->crop_top * (size_t)ctx->stride +
                             (size_t)ctx->crop_left);
        if (ret == 0)
            ret = copy_plane(frame->data[1], frame->linesize[1], pixels, ctx->stride,
                             ctx->out_width, ctx->out_height / 2, available,
                             uv + (size_t)(ctx->crop_top / 2) * (size_t)ctx->stride +
                                 (size_t)ctx->crop_left);
    }
    return ret;
}

static int dequeue_frame(HybrisVp9Context *ctx, AVFrame *frame, int64_t timeout_us)
{
    int attempt;

    for (attempt = 0; attempt < 4; attempt++) {
        HybrisBufferInfo info;
        int ret, copied;

        memset(&info, 0, sizeof(info));
        ret = ctx->api.dequeue_output(ctx->codec, &info, timeout_us);
        if (ret == HYBRIS_TRY_AGAIN || ret == -1)
            return 0;
        if (ret == HYBRIS_FORMAT_CHANGED || ret == -2) {
            read_output_format(ctx);
            timeout_us = 0;
            continue;
        }
        if (ret == HYBRIS_BUFFERS_CHANGED || ret == -3) {
            timeout_us = 0;
            continue;
        }
        if (ret < 0) {
            fprintf(stderr, "gastube: mediacodec dequeue output %d\n", ret);
            return AVERROR_EXTERNAL;
        }
        if (info.flags & HYBRIS_BUFFER_FLAG_EOS) {
            ctx->api.release_output(ctx->codec, info.index, 0);
            return 0;
        }
        if (ctx->drop_old && info.presentation_time_us > 0 &&
            info.presentation_time_us + 80000 < ctx->min_pts) {
            ctx->api.release_output(ctx->codec, info.index, 0);
            continue;
        }
        if (ctx->drop_old && info.presentation_time_us > 0)
            ctx->drop_old = 0;
        if (!ctx->saw_format)
            read_output_format(ctx);
        copied = copy_output(ctx, frame, &info);
        ctx->api.release_output(ctx->codec, info.index, 0);
        if (copied == AVERROR(EAGAIN)) {
            av_frame_unref(frame);
            continue;
        }
        if (copied < 0) {
            av_frame_unref(frame);
            return copied;
        }
        if (info.presentation_time_us > 0)
            frame->pts = info.presentation_time_us;
        return 1;
    }
    return 0;
}

static int queue_encoded(HybrisVp9Context *ctx, const uint8_t *data, int size,
                         int64_t pts, uint32_t flags)
{
    int attempt;

    for (attempt = 0; attempt < 6; attempt++) {
        size_t index = 0;
        HybrisBufferInfo info;
        uint8_t *buffer;
        size_t capacity;
        int ret = ctx->api.dequeue_input(ctx->codec, &index, attempt == 0 ? 0 : 10000);
        if (ret != 0) {
            if (ctx->held && !ctx->held_ready) {
                int got = dequeue_frame(ctx, ctx->held, 0);
                if (got == 1)
                    ctx->held_ready = 1;
            }
            continue;
        }
        buffer = ctx->api.input_buffer(ctx->codec, index);
        capacity = ctx->api.input_capacity(ctx->codec, index);
        if (!buffer || (size_t)size > capacity) {
            fprintf(stderr, "gastube: mediacodec input %d does not fit %zu\n",
                    size, capacity);
            return AVERROR_INVALIDDATA;
        }
        if (size > 0)
            memcpy(buffer, data, size);
        memset(&info, 0, sizeof(info));
        info.index = index;
        info.size = (size_t)size;
        info.presentation_time_us = pts > 0 ? pts : 0;
        info.flags = flags;
        ret = ctx->api.queue_input(ctx->codec, &info);
        if (ret != 0) {
            fprintf(stderr, "gastube: mediacodec queue input %d\n", ret);
            return AVERROR_EXTERNAL;
        }
        return 0;
    }
    fprintf(stderr, "gastube: mediacodec input buffer unavailable\n");
    return AVERROR(EAGAIN);
}

static int vp9_init(AVCodecContext *avctx)
{
    HybrisVp9Context *ctx = avctx->priv_data;
    int ret, configured, csd = 0;

    ctx->held = av_frame_alloc();
    if (!ctx->held)
        return AVERROR(ENOMEM);
    ret = load_api(ctx);
    if (ret < 0)
        return ret;
    ctx->api.init();
    ret = find_qcom(ctx);
    if (ret < 0)
        return ret;
    if (avctx->extradata && avctx->extradata_size > 0) {
        ctx->csd0 = av_malloc(avctx->extradata_size);
        if (!ctx->csd0)
            return AVERROR(ENOMEM);
        memcpy(ctx->csd0, avctx->extradata, avctx->extradata_size);
        ctx->csd0_size = avctx->extradata_size;
    }
    if (avctx->width <= 0 || avctx->height <= 0) {
        fprintf(stderr, "gastube: mediacodec missing picture size\n");
        return AVERROR_INVALIDDATA;
    }
    ctx->format = ctx->api.create_format(ctx->mime, avctx->width, avctx->height,
                                         0, 16 * 1024 * 1024);
    if (!ctx->format) {
        fprintf(stderr, "gastube: mediacodec format failed\n");
        return AVERROR_EXTERNAL;
    }
    if (ctx->csd0 && ctx->csd0_size > 0)
        ctx->api.set_bytes(ctx->format, "csd-0", ctx->csd0, (size_t)ctx->csd0_size);
    configured = ctx->api.configure(ctx->codec, ctx->format, NULL, 0);
    if (configured != 0) {
        fprintf(stderr, "gastube: mediacodec configure=%d\n", configured);
        return AVERROR_EXTERNAL;
    }
    ret = ctx->api.start(ctx->codec);
    if (ret != 0) {
        fprintf(stderr, "gastube: mediacodec start=%d\n", ret);
        return AVERROR_EXTERNAL;
    }
    ctx->started = 1;
    if (ctx->csd0_size > 0)
        csd = ctx->api.queue_csd(ctx->codec, ctx->format);
    fprintf(stderr, "gastube: mediacodec started csd=%d csd_bytes=%d\n",
            csd, ctx->csd0_size);
    return 0;
}

static int vp9_close(AVCodecContext *avctx)
{
    HybrisVp9Context *ctx = avctx->priv_data;

    if (ctx->codec && ctx->started && ctx->api.stop)
        ctx->api.stop(ctx->codec);
    if (ctx->codec && ctx->api.release)
        ctx->api.release(ctx->codec);
    if (ctx->codec && ctx->api.destroy)
        ctx->api.destroy(ctx->codec);
    ctx->codec = NULL;
    if (ctx->format && ctx->api.destroy_format)
        ctx->api.destroy_format(ctx->format);
    ctx->format = NULL;
    av_freep(&ctx->csd0);
    av_frame_free(&ctx->held);
    if (ctx->library)
        dlclose(ctx->library);
    ctx->library = NULL;
    return 0;
}

static void vp9_flush(AVCodecContext *avctx)
{
    HybrisVp9Context *ctx = avctx->priv_data;
    int flushed = -1, restarted = -1, csd = 0;

    if (ctx->held)
        av_frame_unref(ctx->held);
    ctx->held_ready = 0;
    ctx->eos_queued = 0;
    ctx->need_sync = 1;
    ctx->dropped_sync = 0;
    ctx->drop_old = 0;
    ctx->min_pts = 0;
    if (!ctx->codec || !ctx->started || !ctx->api.flush)
        return;
    flushed = ctx->api.flush(ctx->codec);
    if (ctx->api.start)
        restarted = ctx->api.start(ctx->codec);
    if (restarted == 0 && ctx->csd0 && ctx->csd0_size > 0 && ctx->format &&
        ctx->api.queue_csd)
        csd = ctx->api.queue_csd(ctx->codec, ctx->format);
    fprintf(stderr, "gastube: mediacodec flush=%d restart=%d csd=%d\n",
            flushed, restarted, csd);
}

static int vp9_decode(AVCodecContext *avctx, AVFrame *frame, int *got_frame,
                      AVPacket *pkt)
{
    HybrisVp9Context *ctx = avctx->priv_data;
    int ret;

    *got_frame = 0;
    if (!ctx->started)
        return AVERROR_EXTERNAL;

    if (pkt && pkt->size > 0) {
        int64_t pts = 0;
        int profile = vp9_profile(pkt->data, pkt->size);
        uint32_t flags = (pkt->flags & AV_PKT_FLAG_KEY) ? HYBRIS_BUFFER_FLAG_SYNC : 0;
        if (profile >= 2) {
            fprintf(stderr, "gastube: mediacodec vp9 profile=%d\n", profile);
            return AVERROR_INVALIDDATA;
        }
        if (!ctx->logged_profile && profile == 0) {
            ctx->logged_profile = 1;
            fprintf(stderr, "gastube: mediacodec vp9 profile=0\n");
        }
        if (pkt->pts != AV_NOPTS_VALUE && avctx->pkt_timebase.num && avctx->pkt_timebase.den)
            pts = av_rescale_q(pkt->pts, avctx->pkt_timebase, AV_TIME_BASE_Q);
        if (ctx->need_sync && !(pkt->flags & AV_PKT_FLAG_KEY)) {
            ctx->dropped_sync++;
            if (ctx->dropped_sync == 1)
                fprintf(stderr, "gastube: mediacodec wait-sync\n");
            if (ctx->dropped_sync < 120)
                return pkt->size;
            fprintf(stderr, "gastube: mediacodec wait-sync give-up drop=%d\n",
                    ctx->dropped_sync);
        } else if (ctx->need_sync) {
            if (ctx->dropped_sync)
                fprintf(stderr, "gastube: mediacodec sync drop=%d\n",
                        ctx->dropped_sync);
            ctx->min_pts = pts;
            ctx->drop_old = pts > 0;
        }
        ctx->need_sync = 0;
        ctx->dropped_sync = 0;
        ret = queue_encoded(ctx, pkt->data, pkt->size, pts, flags);
        if (ret < 0)
            return ret;
    } else if (!ctx->eos_queued) {
        ret = queue_encoded(ctx, NULL, 0, 0, HYBRIS_BUFFER_FLAG_EOS);
        if (ret == 0)
            ctx->eos_queued = 1;
    }

    if (ctx->held_ready) {
        av_frame_move_ref(frame, ctx->held);
        ctx->held_ready = 0;
        ret = 1;
    } else {
        ret = dequeue_frame(ctx, frame, 0);
    }
    if (ret < 0)
        return ret;
    if (ret > 0) {
        if (frame->pts > 0 && avctx->pkt_timebase.num && avctx->pkt_timebase.den)
            frame->pts = av_rescale_q(frame->pts, AV_TIME_BASE_Q, avctx->pkt_timebase);
        *got_frame = 1;
        if (!ctx->logged_picture) {
            ctx->logged_picture = 1;
            fprintf(stderr, "gastube: decode=mediacodec\n");
        }
    }
    return pkt ? pkt->size : 0;
}

const FFCodec ff_vp9_hybris_decoder = {
    .p.name         = "vp9_hybris",
    .p.long_name    = NULL_IF_CONFIG_SMALL("VP9 via Halium MediaCodec"),
    .p.type         = AVMEDIA_TYPE_VIDEO,
    .p.id           = AV_CODEC_ID_VP9,
    .p.capabilities = AV_CODEC_CAP_DELAY | AV_CODEC_CAP_AVOID_PROBING,
    .priv_data_size = sizeof(HybrisVp9Context),
    .init           = vp9_init,
    .close          = vp9_close,
    .flush          = vp9_flush,
    FF_CODEC_DECODE_CB(vp9_decode),
    .caps_internal  = FF_CODEC_CAP_NOT_INIT_THREADSAFE | FF_CODEC_CAP_INIT_CLEANUP,
};

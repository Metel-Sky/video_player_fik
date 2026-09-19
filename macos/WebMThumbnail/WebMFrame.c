#include "WebMFrame.h"

#include <stdlib.h>
#include <string.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

void fik_free_frame(uint8_t *rgba) {
  free(rgba);
}

bool fik_extract_first_frame(
    const char *path,
    int max_dim,
    uint8_t **rgba,
    int *width,
    int *height
) {
  if (path == NULL || rgba == NULL || width == NULL || height == NULL) {
    return false;
  }
  *rgba = NULL;
  *width = 0;
  *height = 0;
  if (max_dim < 16) max_dim = 16;

  AVFormatContext *fmt = NULL;
  AVCodecContext *codec_ctx = NULL;
  AVPacket *pkt = NULL;
  AVFrame *frame = NULL;
  AVFrame *rgba_frame = NULL;
  struct SwsContext *sws = NULL;
  uint8_t *out = NULL;
  bool ok = false;

  if (avformat_open_input(&fmt, path, NULL, NULL) < 0) goto done;
  if (avformat_find_stream_info(fmt, NULL) < 0) goto done;

  const int vidx = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
  if (vidx < 0) goto done;
  AVStream *st = fmt->streams[vidx];

  const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
  if (codec == NULL) goto done;
  codec_ctx = avcodec_alloc_context3(codec);
  if (codec_ctx == NULL) goto done;
  if (avcodec_parameters_to_context(codec_ctx, st->codecpar) < 0) goto done;
  codec_ctx->pkt_timebase = st->time_base;
  if (avcodec_open2(codec_ctx, codec, NULL) < 0) goto done;

  pkt = av_packet_alloc();
  frame = av_frame_alloc();
  if (pkt == NULL || frame == NULL) goto done;

  int got = 0;
  while (av_read_frame(fmt, pkt) >= 0) {
    if (pkt->stream_index != vidx) {
      av_packet_unref(pkt);
      continue;
    }
    if (avcodec_send_packet(codec_ctx, pkt) >= 0) {
      av_packet_unref(pkt);
      if (avcodec_receive_frame(codec_ctx, frame) == 0) {
        got = 1;
        break;
      }
    } else {
      av_packet_unref(pkt);
    }
  }
  if (!got) {
    avcodec_send_packet(codec_ctx, NULL);
    if (avcodec_receive_frame(codec_ctx, frame) == 0) got = 1;
  }
  if (!got || frame->width <= 0 || frame->height <= 0) goto done;

  int dst_w = frame->width;
  int dst_h = frame->height;
  if (dst_w > max_dim || dst_h > max_dim) {
    const double scale = (double)max_dim / (dst_w > dst_h ? dst_w : dst_h);
    dst_w = (int)(dst_w * scale);
    dst_h = (int)(dst_h * scale);
    if (dst_w < 1) dst_w = 1;
    if (dst_h < 1) dst_h = 1;
  }

  sws = sws_getContext(
      frame->width,
      frame->height,
      (enum AVPixelFormat)frame->format,
      dst_w,
      dst_h,
      AV_PIX_FMT_RGBA,
      SWS_BILINEAR,
      NULL,
      NULL,
      NULL
  );
  if (sws == NULL) goto done;

  rgba_frame = av_frame_alloc();
  if (rgba_frame == NULL) goto done;
  rgba_frame->format = AV_PIX_FMT_RGBA;
  rgba_frame->width = dst_w;
  rgba_frame->height = dst_h;
  if (av_frame_get_buffer(rgba_frame, 32) < 0) goto done;

  sws_scale(
      sws,
      (const uint8_t *const *)frame->data,
      frame->linesize,
      0,
      frame->height,
      rgba_frame->data,
      rgba_frame->linesize
  );

  const int stride = dst_w * 4;
  out = (uint8_t *)malloc((size_t)stride * (size_t)dst_h);
  if (out == NULL) goto done;
  for (int y = 0; y < dst_h; y++) {
    memcpy(out + (size_t)y * (size_t)stride, rgba_frame->data[0] + y * rgba_frame->linesize[0], (size_t)stride);
  }

  *rgba = out;
  *width = dst_w;
  *height = dst_h;
  out = NULL;
  ok = true;

done:
  free(out);
  if (sws) sws_freeContext(sws);
  av_frame_free(&rgba_frame);
  av_frame_free(&frame);
  av_packet_free(&pkt);
  avcodec_free_context(&codec_ctx);
  avformat_close_input(&fmt);
  return ok;
}

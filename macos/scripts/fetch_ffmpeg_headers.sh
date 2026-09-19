#!/bin/sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Vendor/ffmpeg-n6.0"
if [ -f "$DEST/libavformat/avformat.h" ] && [ -f "$DEST/libavutil/avconfig.h" ]; then
  exit 0
fi
TMP="$(mktemp -d)"
curl -L --fail -o "$TMP/ffmpeg.tar.gz" https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n6.0.tar.gz
tar -xzf "$TMP/ffmpeg.tar.gz" -C "$TMP"
mkdir -p "$DEST"
for d in libavcodec libavformat libavutil libswscale; do
  mkdir -p "$DEST/$d"
  find "$TMP/FFmpeg-n6.0/$d" -name '*.h' | while read -r f; do
    rel="${f#"$TMP/FFmpeg-n6.0/"}"
    mkdir -p "$DEST/$(dirname "$rel")"
    cp "$f" "$DEST/$rel"
  done
done
cat > "$DEST/libavutil/avconfig.h" <<'EOF'
#ifndef AVUTIL_AVCONFIG_H
#define AVUTIL_AVCONFIG_H
#define AV_HAVE_BIGENDIAN 0
#define AV_HAVE_FAST_UNALIGNED 1
#endif
EOF
cat > "$DEST/libavutil/ffversion.h" <<'EOF'
#ifndef AVUTIL_FFVERSION_H
#define AVUTIL_FFVERSION_H
#define FFMPEG_VERSION "6.0"
#endif
EOF
cat > "$DEST/config.h" <<'EOF'
#define ARCH_AARCH64 1
#define HAVE_BIGENDIAN 0
EOF
rm -rf "$TMP"

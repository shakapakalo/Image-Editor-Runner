#!/bin/bash
# ============================================================
#  Grok2API — Auto Cleanup
#  Deletes all video and image temp files
#  Runs via cron every 10 minutes
# ============================================================

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
VIDEO_DIR="$INSTALL_DIR/data/tmp/video"
IMAGE_DIR="$INSTALL_DIR/data/tmp/image"
LOG_FILE="$INSTALL_DIR/logs/cleanup.log"

mkdir -p "$INSTALL_DIR/logs"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

video_count=0
image_count=0

if [ -d "$VIDEO_DIR" ]; then
    video_count=$(find "$VIDEO_DIR" -type f | wc -l)
    find "$VIDEO_DIR" -type f -delete
fi

if [ -d "$IMAGE_DIR" ]; then
    image_count=$(find "$IMAGE_DIR" -type f | wc -l)
    find "$IMAGE_DIR" -type f -delete
fi

echo "$TIMESTAMP | Deleted: $video_count video(s), $image_count image(s)" >> "$LOG_FILE"

# Keep log file small (last 200 lines only)
tail -200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"

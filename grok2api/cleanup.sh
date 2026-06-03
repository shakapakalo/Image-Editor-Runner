#!/bin/bash
# ============================================================
#  Grok2API — Auto Cleanup
#  Deletes video and image files older than 20 minutes
#  Runs via cron every 5 minutes
# ============================================================

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$INSTALL_DIR/data"
LOG_FILE="$INSTALL_DIR/logs/cleanup.log"
MAX_AGE_MINUTES=20

mkdir -p "$INSTALL_DIR/logs"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

video_count=0
image_count=0
total_freed=0

if [ -d "$DATA_DIR" ]; then
    # Delete video files older than MAX_AGE_MINUTES
    while IFS= read -r -d '' file; do
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        rm -f "$file"
        total_freed=$((total_freed + size))
        video_count=$((video_count + 1))
    done < <(find "$DATA_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mov" \) -mmin +${MAX_AGE_MINUTES} -print0 2>/dev/null)

    # Delete image files older than MAX_AGE_MINUTES
    while IFS= read -r -d '' file; do
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        rm -f "$file"
        total_freed=$((total_freed + size))
        image_count=$((image_count + 1))
    done < <(find "$DATA_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) -mmin +${MAX_AGE_MINUTES} -print0 2>/dev/null)

    # Remove empty subdirectories (keep data/ itself)
    find "$DATA_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true
fi

# Log only if something was deleted
if [ $((video_count + image_count)) -gt 0 ]; then
    freed_mb=$(echo "scale=2; $total_freed / 1048576" | bc 2>/dev/null || echo "?")
    echo "$TIMESTAMP | Deleted: ${video_count} video(s), ${image_count} image(s) | Freed: ${freed_mb} MB" >> "$LOG_FILE"
fi

# Keep log file small (last 500 lines only)
if [ -f "$LOG_FILE" ]; then
    tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

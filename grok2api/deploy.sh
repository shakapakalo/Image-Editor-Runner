#!/bin/bash
# ============================================================
#  Grok2API — One-Click Deploy / Restart
#  Usage: bash deploy.sh
#  - Kills any process on port 8885
#  - Starts fresh instance
#  - Logs to logs/grok2api.log
# ============================================================

PORT=8885
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$INSTALL_DIR/logs/grok2api.log"
PID_FILE="$INSTALL_DIR/logs/grok2api.pid"

mkdir -p "$INSTALL_DIR/logs"

echo "=============================="
echo "  Grok2API Deploy"
echo "  Port: $PORT"
echo "  Dir : $INSTALL_DIR"
echo "=============================="

# --- Kill existing process on port 8885 ---
echo "[1/3] Killing any process on port $PORT..."

# Method 1: fuser (most reliable, available everywhere)
if command -v fuser &>/dev/null; then
    fuser -k ${PORT}/tcp 2>/dev/null && echo "  Killed via fuser" || true

# Method 2: ss + awk + kill
elif command -v ss &>/dev/null; then
    PIDS=$(ss -tlnp "sport = :${PORT}" 2>/dev/null | grep -oP 'pid=\K[0-9]+')
    for pid in $PIDS; do
        kill -9 "$pid" 2>/dev/null && echo "  Killed PID $pid" || true
    done

# Method 3: lsof
elif command -v lsof &>/dev/null; then
    OLD_PIDS=$(lsof -ti tcp:$PORT 2>/dev/null || true)
    for pid in $OLD_PIDS; do
        kill -9 "$pid" 2>/dev/null && echo "  Killed PID $pid" || true
    done

# Method 4: /proc scan
else
    for pid in $(ls /proc | grep -E '^[0-9]+$'); do
        if [ -f "/proc/$pid/net/tcp" ]; then
            HEX_PORT=$(printf '%04X' $PORT)
            if grep -q ":${HEX_PORT}" /proc/$pid/net/tcp6 2>/dev/null || \
               grep -q ":${HEX_PORT}" /proc/$pid/net/tcp 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null && echo "  Killed PID $pid" || true
            fi
        fi
    done
fi

# Also kill by PID file
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill -9 "$OLD_PID" 2>/dev/null && echo "  Killed old PID $OLD_PID from pidfile" || true
    rm -f "$PID_FILE"
fi

sleep 2
echo "  Port $PORT is free."

# --- Setup cleanup cron if not already set ---
chmod +x "$INSTALL_DIR/cleanup.sh" 2>/dev/null || true
CRON_JOB="*/10 * * * * bash $INSTALL_DIR/cleanup.sh"
if ! crontab -l 2>/dev/null | grep -q "cleanup.sh"; then
    ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
    echo "  Auto-cleanup cron added (every 10 min)"
fi

# --- Check uv ---
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv &>/dev/null; then
    echo "[2/3] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "[2/3] uv found: $(uv --version)"
fi

# --- Start server ---
echo "[3/3] Starting Grok2API on port $PORT..."
cd "$INSTALL_DIR"

nohup uv run uvicorn main:app \
    --host 0.0.0.0 \
    --port $PORT \
    --workers 1 \
    >> "$LOG_FILE" 2>&1 &

NEW_PID=$!
echo $NEW_PID > "$PID_FILE"

sleep 3

# --- Verify ---
if kill -0 $NEW_PID 2>/dev/null; then
    echo ""
    echo "=============================="
    echo "  Grok2API started!"
    echo "  PID : $NEW_PID"
    echo "  Port: $PORT"
    echo "  Log : $LOG_FILE"
    echo ""
    echo "  Test: curl http://localhost:$PORT/v1/models"
    echo "  Stop: kill \$(cat $PID_FILE)"
    echo "  Logs: tail -f $LOG_FILE"
    echo "=============================="
else
    echo "  ERROR: Failed to start. Check logs:"
    tail -20 "$LOG_FILE"
    exit 1
fi

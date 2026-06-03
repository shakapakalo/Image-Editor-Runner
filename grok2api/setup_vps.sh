#!/bin/bash
# ============================================================
#  Grok2API — VPS First-Time Setup
#  Run once: bash setup_vps.sh
# ============================================================
set -e

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="grok2api"
PORT=8885

echo "=============================="
echo "  Grok2API VPS Setup"
echo "  Dir : $INSTALL_DIR"
echo "  Port: $PORT"
echo "=============================="

# 1. Install uv (Python package manager)
if ! command -v uv &>/dev/null; then
    echo "[1/4] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    echo "[1/4] uv already installed: $(uv --version)"
fi

# 2. Install Python deps
echo "[2/4] Installing Python dependencies..."
cd "$INSTALL_DIR"
uv sync --frozen

# 3. Install systemd service
echo "[3/4] Installing systemd service..."
UV_BIN=$(command -v uv)
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Grok2API Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$UV_BIN run uvicorn main:app --host 0.0.0.0 --port $PORT --workers 1
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}

# 4. Setup cron — auto delete video/image every 10 minutes
echo "[4/5] Setting up auto-cleanup cron (every 10 min)..."
chmod +x "$INSTALL_DIR/cleanup.sh"
CRON_JOB="*/10 * * * * bash $INSTALL_DIR/cleanup.sh"
# Add only if not already present
( crontab -l 2>/dev/null | grep -v "cleanup.sh" ; echo "$CRON_JOB" ) | crontab -
echo "  Cron set: $CRON_JOB"

# 5. Start service
echo "[5/5] Starting Grok2API on port $PORT..."
systemctl restart ${SERVICE_NAME}
sleep 2
systemctl status ${SERVICE_NAME} --no-pager

echo ""
echo "=============================="
echo "  Done! Grok2API running on port $PORT"
echo "  Commands:"
echo "    systemctl status grok2api"
echo "    systemctl restart grok2api"
echo "    journalctl -u grok2api -f"
echo "    tail -f $INSTALL_DIR/logs/cleanup.log"
echo "=============================="

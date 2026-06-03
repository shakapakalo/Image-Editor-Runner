#!/bin/bash
# ============================================================
#  Grok2API — One-Paste Full Install
#  Contabo / any Ubuntu/Debian VPS
#
#  USAGE (run as root):
#  bash <(curl -fsSL https://raw.githubusercontent.com/shakapakalo/Image-Editor-Runner/main/grok2api/install.sh)
# ============================================================
set -e

REPO_URL="https://github.com/shakapakalo/Image-Editor-Runner"
REPO_DIR="/root/Image-Editor-Runner"
WORK_DIR="$REPO_DIR/grok2api"
SERVICE_NAME="grok2api"
PORT=8885
BRANCH="main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Grok2API — Full Installer       ║${NC}"
echo -e "${CYAN}║  Port: $PORT  |  Dir: $WORK_DIR  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── 0. Root check ────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash install.sh"
fi

# ── 1. Kill port 8885 ────────────────────────────────────────
info "Killing anything on port $PORT..."
if command -v fuser &>/dev/null; then
    fuser -k ${PORT}/tcp 2>/dev/null || true
else
    OLD_PIDS=$(ss -tlnp "sport = :${PORT}" 2>/dev/null | grep -oP 'pid=\K[0-9]+' || true)
    for pid in $OLD_PIDS; do kill -9 "$pid" 2>/dev/null || true; done
fi

# Stop existing systemd service if running
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
fi

sleep 1
success "Port $PORT is free"

# ── 2. Install system deps ───────────────────────────────────
info "Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl bc 2>/dev/null
success "System deps ready"

# ── 3. Clone / update repo ──────────────────────────────────
if [ -d "$REPO_DIR/.git" ]; then
    info "Updating existing repo..."
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard origin/$BRANCH
    success "Repo updated"
else
    info "Cloning repo..."
    rm -rf "$REPO_DIR"
    git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
    success "Repo cloned to $REPO_DIR"
fi

cd "$WORK_DIR"

# ── 4. Install uv ────────────────────────────────────────────
info "Installing uv (Python manager)..."
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    export PATH="$HOME/.local/bin:$PATH"
fi
success "uv: $(uv --version)"

# ── 5. Install Python deps ───────────────────────────────────
info "Installing Python dependencies..."
uv sync --frozen 2>/dev/null || uv sync
success "Python deps installed"

# ── 6. Setup data dirs ───────────────────────────────────────
info "Creating data directories..."
mkdir -p data logs
chmod +x cleanup.sh 2>/dev/null || true

# Create default token.json if missing
if [ ! -f "data/token.json" ]; then
    cat > data/token.json << 'TOKEOF'
{
  "ssoSuper": []
}
TOKEOF
    warn "data/token.json created (empty) — add your SSO token via /admin panel"
fi

# Create default config.toml if missing
if [ ! -f "data/config.toml" ]; then
    cp config.defaults.toml data/config.toml
    warn "data/config.toml created from defaults — edit as needed"
fi

success "Data dirs ready"

# ── 7. Install systemd service ───────────────────────────────
info "Installing systemd service..."
UV_BIN=$(command -v uv)
WORK_DIR="$(pwd)"

cat > /etc/systemd/system/${SERVICE_NAME}.service << SVCEOF
[Unit]
Description=Grok2API Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
Environment=PATH=${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${UV_BIN} run uvicorn main:app --host 0.0.0.0 --port ${PORT} --workers 1
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
success "Systemd service installed & enabled"

# ── 8. Setup cron — delete files older than 20 min ──────────
info "Setting up auto-cleanup cron (every 5 min, removes >20 min files)..."
CRON_JOB="*/5 * * * * bash ${WORK_DIR}/cleanup.sh"
( crontab -l 2>/dev/null | grep -v "cleanup.sh" ; echo "$CRON_JOB" ) | crontab -
success "Cron set: $CRON_JOB"

# ── 9. Start service ─────────────────────────────────────────
info "Starting Grok2API on port $PORT..."
systemctl restart "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Service is running!"
else
    warn "Service may have failed. Check: journalctl -u grok2api -n 50"
fi

# ── 10. Quick test ───────────────────────────────────────────
info "Testing API..."
sleep 2
RESP=$(curl -sf http://localhost:${PORT}/v1/models 2>/dev/null || echo "")
if echo "$RESP" | grep -q "object"; then
    success "API responding on port $PORT ✓"
else
    warn "API not responding yet — wait a few seconds, or check: journalctl -u grok2api -f"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Grok2API is LIVE! 🚀              ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  API  : http://YOUR_IP:${PORT}/v1         ║${NC}"
echo -e "${GREEN}║  Admin: http://YOUR_IP:${PORT}/admin      ║${NC}"
echo -e "${GREEN}║  Pass : grok2api                          ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Useful commands:                         ║${NC}"
echo -e "${GREEN}║  systemctl status grok2api                ║${NC}"
echo -e "${GREEN}║  systemctl restart grok2api               ║${NC}"
echo -e "${GREEN}║  journalctl -u grok2api -f                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next: Add your SSO token at http://YOUR_IP:${PORT}/admin${NC}"
echo ""

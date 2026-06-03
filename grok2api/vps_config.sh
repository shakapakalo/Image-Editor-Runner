#!/bin/bash
# ============================================================
#  Grok2API — VPS Config Setup
#  Run after copying files to VPS:  bash vps_config.sh
#  Sets app_url to your VPS IP/domain on port 8885
# ============================================================

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$INSTALL_DIR/data/config.toml"
PORT=8885

# Auto-detect VPS public IP — force IPv4 with -4 flag
VPS_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s api.ipify.org 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || echo "")

echo "=============================="
echo "  Grok2API VPS Config"
echo "=============================="

if [ -z "$VPS_IP" ]; then
    echo "  Could not auto-detect IP."
    read -p "  Enter your VPS IP or domain: " VPS_IP
fi

echo "  VPS IP/Domain: $VPS_IP"
echo "  Port: $PORT"
echo ""

# Update app_url in config.toml
APP_URL="http://${VPS_IP}:${PORT}"

if [ -f "$CONFIG_FILE" ]; then
    sed -i "s|app_url = \".*\"|app_url = \"${APP_URL}\"|g" "$CONFIG_FILE"
    echo "  app_url updated to: $APP_URL"
else
    # Create config.toml from scratch
    mkdir -p "$INSTALL_DIR/data"
    cat > "$CONFIG_FILE" <<EOF
[app]
app_url = "${APP_URL}"
api_key = "ranaji"
app_key = "ranaji"
image_format = "url"
video_format = "url"
temporary = true
disable_memory = true
stream = true
thinking = true
dynamic_statsig = true
filter_tags = ["xaiartifact","xai:tool_usage_card","grok:render"]

[proxy]
base_proxy_url = ""
asset_proxy_url = ""
enabled = false

[retry]
max_retry = 3
retry_status_codes = [401,429,403]
retry_backoff_base = 0.5
retry_backoff_factor = 2.0
retry_backoff_max = 20.0
retry_budget = 60.0

[chat]
concurrent = 50
timeout = 300
stream_timeout = 300

[image]
timeout = 60
stream_timeout = 60
final_timeout = 15
nsfw = true

[video]
concurrent = 100
timeout = 600
stream_timeout = 300

[asset]
upload_timeout = 60
download_timeout = 60
delete_timeout = 60
EOF
    echo "  config.toml created."
fi

echo ""
echo "  Config file: $CONFIG_FILE"
echo "  app_url set to: $APP_URL"
echo ""
echo "  Now run: bash deploy.sh"
echo "=============================="

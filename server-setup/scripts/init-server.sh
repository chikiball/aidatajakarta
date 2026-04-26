#!/bin/bash
# ═══════════════════════════════════════════════════
# Full server setup — Cloudflare Tunnel + Nginx + App
#
# Prerequisites:
#   1. Ubuntu server with Docker installed
#   2. A Cloudflare account with a domain
#   3. A Tunnel token from Cloudflare Zero Trust dashboard
#
# Usage:
#   sudo bash init-server.sh <CLOUDFLARE_TUNNEL_TOKEN>
#
# If you don't have the token yet, run without it —
# the script will set up everything else and tell you
# how to add the tunnel later.
# ═══════════════════════════════════════════════════
set -euo pipefail

CF_TOKEN="${1:-}"
SERVER="/home/nandha/server"

echo ""
echo "═══════════════════════════════════════════"
echo "  🏗️  Setting up secure multi-site server"
echo "═══════════════════════════════════════════"
echo ""

# ─── 1. Folder structure ───
echo "1/6  Creating folders..."
mkdir -p "$SERVER"/{nginx/conf.d,nginx/certs,sites,scripts,security}

# ─── 2. Docker network ───
echo "2/6  Creating Docker network: server-net..."
docker network create server-net 2>/dev/null && echo "     ✅ Created" || echo "     ✅ Already exists"

# ─── 3. Nginx gateway + Cloudflare Tunnel ───
echo "3/6  Setting up Nginx gateway + Cloudflare Tunnel..."

# Copy nginx configs
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cp "$SETUP_DIR/nginx/nginx.conf"          "$SERVER/nginx/"
cp "$SETUP_DIR/nginx/aidatajakarta.conf"  "$SERVER/nginx/conf.d/"
cp "$SETUP_DIR/docker-compose.yml"        "$SERVER/docker-compose.yml"

# Create .env with tunnel token
cat > "$SERVER/.env" << ENV
CF_TUNNEL_TOKEN=${CF_TOKEN}
ENV

cd "$SERVER"
if [ -n "$CF_TOKEN" ]; then
    docker compose up -d
    echo "     ✅ Nginx + Cloudflare Tunnel running"
else
    # Start nginx only, skip tunnel
    docker compose up -d nginx
    echo "     ✅ Nginx running (tunnel skipped — add token later)"
    echo ""
    echo "     ⚠️  To enable Cloudflare Tunnel later:"
    echo "        1. Get token from https://one.dash.cloudflare.com → Networks → Tunnels"
    echo "        2. echo 'CF_TUNNEL_TOKEN=your-token' > $SERVER/.env"
    echo "        3. cd $SERVER && docker compose up -d"
fi

# ─── 4. Deploy aidatajakarta ───
echo "4/6  Deploying aidatajakarta..."
SITE_DIR="$SERVER/sites/aidatajakarta"

if [ -d "$SITE_DIR" ]; then
    echo "     Already cloned, pulling latest..."
    cd "$SITE_DIR" && git pull origin main
else
    git clone https://github.com/chikiball/aidatajakarta.git "$SITE_DIR"
fi

cd "$SITE_DIR"
docker compose up -d --build

# Reload nginx to pick up config
docker exec nginx-gateway nginx -s reload 2>/dev/null || true
echo "     ✅ aidatajakarta deployed"

# ─── 5. Copy management scripts ───
echo "5/6  Installing management scripts..."
cp "$SETUP_DIR/scripts/deploy-site.sh" "$SERVER/scripts/"
cp "$SETUP_DIR/scripts/status.sh"      "$SERVER/scripts/"
cp "$SETUP_DIR/scripts/add-site.sh"    "$SERVER/scripts/"
cp "$SETUP_DIR/security/harden-os.sh"  "$SERVER/security/"
chmod +x "$SERVER/scripts/"*.sh "$SERVER/security/"*.sh

# ─── 6. OS hardening ───
echo "6/6  Running OS hardening..."
bash "$SERVER/security/harden-os.sh"

# ─── Done ───
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')
echo ""
echo "═══════════════════════════════════════════"
echo "  ✅  Server is live and hardened!"
echo ""
if [ -n "$CF_TOKEN" ]; then
    echo "  🌐 Access via your Cloudflare domain"
    echo "  🔒 Home IP is hidden — zero exposed ports"
else
    echo "  🏠 LAN access: http://$SERVER_IP (direct)"
    echo "  ⚠️  Add Cloudflare Tunnel token for public access"
fi
echo ""
echo "  Commands:"
echo "    sudo bash $SERVER/scripts/status.sh"
echo "    sudo bash $SERVER/scripts/deploy-site.sh aidatajakarta"
echo "═══════════════════════════════════════════"

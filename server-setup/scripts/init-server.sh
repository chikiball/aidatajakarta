#!/bin/bash
# ═══════════════════════════════════════════════════
# One-time server bootstrap
# Creates /home/nandha/server/ structure, starts
# the Nginx gateway container, deploys aidatajakarta.
#
# Usage:  sudo bash init-server.sh
# ═══════════════════════════════════════════════════
set -euo pipefail

SERVER="/home/nandha/server"

echo ""
echo "═══════════════════════════════════════════"
echo "  🏗️  Setting up multi-site home server"
echo "═══════════════════════════════════════════"
echo ""

# ─── 1. Create folder structure ───
echo "1/5  Creating folders..."
mkdir -p "$SERVER"/{nginx/conf.d,nginx/certs,sites,scripts}

# ─── 2. Create the shared Docker network ───
echo "2/5  Creating Docker network: server-net..."
docker network create server-net 2>/dev/null && echo "     ✅ Created" || echo "     ✅ Already exists"

# ─── 3. Set up Nginx gateway ───
echo "3/5  Starting Nginx gateway container..."

cat > "$SERVER/docker-compose.yml" << 'DC'
services:
  nginx:
    image: nginx:alpine
    container_name: nginx-gateway
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    networks:
      - server-net

networks:
  server-net:
    external: true
DC

cd "$SERVER"
docker compose up -d
echo "     ✅ Nginx gateway running on :80"

# ─── 4. Clone & deploy aidatajakarta ───
echo "4/5  Deploying aidatajakarta..."
SITE_DIR="$SERVER/sites/aidatajakarta"

if [ -d "$SITE_DIR" ]; then
    echo "     Site already cloned, pulling latest..."
    cd "$SITE_DIR" && git pull origin main
else
    git clone https://github.com/chikiball/aidatajakarta.git "$SITE_DIR"
fi

cd "$SITE_DIR"
docker compose up -d --build

# Copy nginx config for this site
cp "$SITE_DIR/server-setup/nginx/aidatajakarta.conf" "$SERVER/nginx/conf.d/"

# Reload nginx to pick up the new config
docker exec nginx-gateway nginx -s reload
echo "     ✅ aidatajakarta deployed"

# ─── 5. Copy management scripts ───
echo "5/5  Installing management scripts..."
cp "$SITE_DIR/server-setup/scripts/deploy-site.sh" "$SERVER/scripts/"
cp "$SITE_DIR/server-setup/scripts/status.sh"      "$SERVER/scripts/"
cp "$SITE_DIR/server-setup/scripts/add-site.sh"    "$SERVER/scripts/"
chmod +x "$SERVER/scripts/"*.sh

# ─── Done ───
echo ""
echo "═══════════════════════════════════════════"
echo "  ✅  Server is live!"
echo ""
echo "  Open:   http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')"
echo ""
echo "  Manage:"
echo "    sudo bash $SERVER/scripts/status.sh"
echo "    sudo bash $SERVER/scripts/deploy-site.sh aidatajakarta"
echo "    sudo bash $SERVER/scripts/add-site.sh <name> <repo> <port>"
echo "═══════════════════════════════════════════"

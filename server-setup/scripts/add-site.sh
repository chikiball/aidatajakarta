#!/bin/bash
# ═══════════════════════════════════════════════════
# Scaffold a new site
# Usage: sudo bash add-site.sh <name> <git-repo-url> <port>
# Example: sudo bash add-site.sh myportfolio https://github.com/user/portfolio.git 8082
# ═══════════════════════════════════════════════════
set -euo pipefail

NAME="${1:?Usage: add-site.sh <name> <git-repo-url> <port>}"
REPO="${2:?Provide git repo URL}"
PORT="${3:?Provide host port (e.g. 8082)}"

SERVER_ROOT="/home/nandha/server"
SITE_DIR="$SERVER_ROOT/sites/$NAME"
NGINX_CONF="$SERVER_ROOT/nginx/conf.d/$NAME.conf"

# Check port not already taken
if grep -q "^$PORT " "$SERVER_ROOT/ports.conf" 2>/dev/null; then
    echo "❌ Port $PORT is already registered in ports.conf"
    exit 1
fi

if [ -d "$SITE_DIR" ]; then
    echo "❌ Site directory already exists: $SITE_DIR"
    exit 1
fi

echo "═══ Adding site: $NAME (port $PORT) ═══"

# Clone
echo "⬇️  Cloning $REPO ..."
git clone "$REPO" "$SITE_DIR"

# Create .env
cat > "$SITE_DIR/.env" << ENV
COMPOSE_PROJECT_NAME=$NAME
HOST_PORT=$PORT
ENV
echo "  ✅ .env created (port $PORT)"

# Generate Nginx config
cat > "$NGINX_CONF" << NGINX
server {
    listen 80;
    server_name $NAME.local;  # ← change to real domain

    add_header X-Frame-Options        "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 256;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }
}
NGINX
echo "  ✅ Nginx config: $NGINX_CONF"

# Register port
echo "$PORT  $NAME  active" >> "$SERVER_ROOT/ports.conf"
echo "  ✅ Registered in ports.conf"

# Reload Nginx
nginx -t && systemctl reload nginx
echo "  ✅ Nginx reloaded"

echo ""
echo "📋 Next steps:"
echo "   1. Check $SITE_DIR has a docker-compose.yml (and .env with HOST_PORT)"
echo "   2. Run:  sudo bash $SERVER_ROOT/scripts/deploy-site.sh $NAME"
echo "   3. Edit server_name in $NGINX_CONF if using a domain"
echo ""

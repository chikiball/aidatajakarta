#!/bin/bash
# ═══════════════════════════════════════════════════
# Scaffold a new site
# Usage: sudo bash add-site.sh <name> <git-repo-url> [internal-port]
#
# Example:
#   sudo bash add-site.sh myportfolio https://github.com/user/portfolio.git 3000
#
# The site's docker-compose.yml must:
#   - Set container_name: <name>
#   - Use network: server-net (external: true)
#   - Expose its internal port (default: 8080)
# ═══════════════════════════════════════════════════
set -euo pipefail

NAME="${1:?Usage: add-site.sh <name> <git-repo-url> [internal-port]}"
REPO="${2:?Provide git repo URL}"
PORT="${3:-8080}"

SERVER="/home/nandha/server"
SITE_DIR="$SERVER/sites/$NAME"
NGINX_CONF="$SERVER/nginx/conf.d/$NAME.conf"

if [ -d "$SITE_DIR" ]; then
    echo "❌ Already exists: $SITE_DIR"
    exit 1
fi

echo "═══ Adding site: $NAME ═══"

# Clone
echo "⬇️  Cloning $REPO ..."
git clone "$REPO" "$SITE_DIR"

# Generate Nginx config (proxies to container by name)
cat > "$NGINX_CONF" << NGINX
server {
    listen 80;
    server_name ${NAME}.local;  # ← change to real domain

    add_header X-Frame-Options        "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 256;

    location / {
        proxy_pass http://${NAME}:${PORT};
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }
}
NGINX
echo "  ✅ Nginx config: $NGINX_CONF"

# Reload nginx
docker exec nginx-gateway nginx -s reload
echo "  ✅ Nginx reloaded"

echo ""
echo "📋 Next steps:"
echo "   1. Ensure $SITE_DIR/docker-compose.yml uses:"
echo "        container_name: $NAME"
echo "        networks: [server-net]    (with server-net external: true)"
echo "   2. Run:  sudo bash $SERVER/scripts/deploy-site.sh $NAME"
echo "   3. Edit server_name in $NGINX_CONF to your domain"
echo ""

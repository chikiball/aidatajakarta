#!/bin/bash
# ═══════════════════════════════════════════════════
# Deploy / redeploy a site
# Usage: sudo bash deploy-site.sh <sitename>
# ═══════════════════════════════════════════════════
set -euo pipefail

SITE="${1:?Usage: deploy-site.sh <sitename>}"
SERVER="/home/nandha/server"
SITE_DIR="$SERVER/sites/$SITE"

if [ ! -d "$SITE_DIR" ]; then
    echo "❌ Not found: $SITE_DIR"
    exit 1
fi

echo "═══ Deploying: $SITE ═══"
cd "$SITE_DIR"

echo "⬇️  Pulling latest..."
git pull origin main

echo "🔨 Building..."
docker compose build

echo "🔄 Starting..."
docker compose up -d

# Copy nginx config if it exists in the repo
if [ -f "$SITE_DIR/server-setup/nginx/$SITE.conf" ]; then
    cp "$SITE_DIR/server-setup/nginx/$SITE.conf" "$SERVER/nginx/conf.d/"
    docker exec nginx-gateway nginx -s reload
    echo "🔄 Nginx reloaded"
fi

echo "⏳ Health check..."
for i in $(seq 1 24); do
    if docker exec "$SITE" curl -sf http://localhost:8080/ > /dev/null 2>&1; then
        echo "✅ $SITE is healthy!"
        exit 0
    fi
    sleep 5
done

echo "⚠️  Timed out — check: cd $SITE_DIR && docker compose logs --tail 50"
exit 1

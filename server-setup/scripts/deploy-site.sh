#!/bin/bash
# ═══════════════════════════════════════════════════
# Deploy / redeploy a site
# Usage: sudo bash deploy-site.sh <sitename>
# ═══════════════════════════════════════════════════
set -euo pipefail

SITE="${1:?Usage: deploy-site.sh <sitename>}"
SERVER_ROOT="/home/nandha/server"
SITE_DIR="$SERVER_ROOT/sites/$SITE"

if [ ! -d "$SITE_DIR" ]; then
    echo "❌ Site directory not found: $SITE_DIR"
    exit 1
fi

echo "═══ Deploying: $SITE ═══"
cd "$SITE_DIR"

# Pull latest
echo "⬇️  Pulling latest code..."
git pull origin main

# Build & restart
echo "🔨 Building container..."
docker compose build

echo "🔄 Starting container..."
docker compose up -d

# Read port from .env
HOST_PORT=$(grep -E '^HOST_PORT=' .env 2>/dev/null | cut -d= -f2 || echo "?")

echo "⏳ Waiting for health check on :$HOST_PORT ..."
for i in $(seq 1 24); do
    if curl -sf "http://localhost:$HOST_PORT/" > /dev/null 2>&1; then
        echo "✅ $SITE is live on port $HOST_PORT"
        exit 0
    fi
    sleep 5
done

echo "⚠️  Health check timed out — check: docker compose -f $SITE_DIR/docker-compose.yml logs --tail 50"
exit 1

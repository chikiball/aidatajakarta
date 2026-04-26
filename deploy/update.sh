#!/bin/bash
# ──────────────────────────────────────────────
# Jakarta AI Transport — pull & redeploy script
# Run:  sudo bash /opt/aidatajakarta/deploy/update.sh
# ──────────────────────────────────────────────
set -euo pipefail
APP_DIR="/opt/aidatajakarta"

echo "⬇️  Pulling latest code..."
cd "$APP_DIR"
git pull origin main

echo "🔨 Rebuilding container..."
docker compose build --no-cache

echo "🔄 Restarting..."
docker compose up -d

echo "⏳ Waiting for health check (up to 2 min)..."
for i in $(seq 1 24); do
    if curl -sf http://localhost:8080/api/update-status > /dev/null 2>&1; then
        echo "✅ App is healthy!"
        exit 0
    fi
    sleep 5
done

echo "⚠️  Health check timed out — check logs:"
echo "   docker compose logs --tail 50"
exit 1

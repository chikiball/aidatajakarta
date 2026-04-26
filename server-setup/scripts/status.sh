#!/bin/bash
# ═══════════════════════════════════════════════════
# Check status of all sites
# Usage: sudo bash status.sh
# ═══════════════════════════════════════════════════
SERVER_ROOT="/home/nandha/server"
SITES_DIR="$SERVER_ROOT/sites"

echo "═══════════════════════════════════════════"
echo "  🏠 Home Server — Site Status"
echo "═══════════════════════════════════════════"
echo ""
printf "  %-20s %-6s %-12s %s\n" "SITE" "PORT" "CONTAINER" "HEALTH"
printf "  %-20s %-6s %-12s %s\n" "────────────────────" "──────" "────────────" "──────"

for SITE_DIR in "$SITES_DIR"/*/; do
    [ -d "$SITE_DIR" ] || continue
    SITE=$(basename "$SITE_DIR")

    # Read port from .env
    PORT=$(grep -E '^HOST_PORT=' "$SITE_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "-")

    # Check Docker container
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$SITE" 2>/dev/null || echo "not found")

    # Health check
    if [ "$PORT" != "-" ] && curl -sf "http://localhost:$PORT/" > /dev/null 2>&1; then
        HEALTH="🟢 healthy"
    elif [ "$CONTAINER_STATUS" = "running" ]; then
        HEALTH="🟡 running (no http)"
    else
        HEALTH="🔴 down"
    fi

    printf "  %-20s %-6s %-12s %s\n" "$SITE" "$PORT" "$CONTAINER_STATUS" "$HEALTH"
done

echo ""
echo "  Docker containers:"
docker ps --format "    {{.Names}}  {{.Status}}  {{.Ports}}" 2>/dev/null || echo "    (docker not available)"
echo ""
echo "  Nginx status:"
echo "    $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo "═══════════════════════════════════════════"

#!/bin/bash
# ═══════════════════════════════════════════════════
# Dashboard — check all sites
# Usage: sudo bash status.sh
# ═══════════════════════════════════════════════════
SERVER="/home/nandha/server"

echo ""
echo "═══════════════════════════════════════════"
echo "  🏠 Home Server Status"
echo "═══════════════════════════════════════════"
echo ""

# Nginx gateway
NGINX_STATUS=$(docker inspect --format='{{.State.Status}}' nginx-gateway 2>/dev/null || echo "not running")
if [ "$NGINX_STATUS" = "running" ]; then
    echo "  🟢 nginx-gateway    running    :80 :443"
else
    echo "  🔴 nginx-gateway    $NGINX_STATUS"
fi
echo ""

printf "  %-22s %-14s %s\n" "SITE" "CONTAINER" "HEALTH"
printf "  %-22s %-14s %s\n" "──────────────────────" "──────────────" "──────"

for SITE_DIR in "$SERVER/sites"/*/; do
    [ -d "$SITE_DIR" ] || continue
    SITE=$(basename "$SITE_DIR")

    STATUS=$(docker inspect --format='{{.State.Status}}' "$SITE" 2>/dev/null || echo "not found")

    if [ "$STATUS" = "running" ]; then
        HEALTHY=$(docker inspect --format='{{.State.Health.Status}}' "$SITE" 2>/dev/null || echo "none")
        case "$HEALTHY" in
            healthy)  HEALTH="🟢 healthy" ;;
            starting) HEALTH="🟡 starting" ;;
            *)        HEALTH="🟡 running" ;;
        esac
    else
        HEALTH="🔴 $STATUS"
    fi

    printf "  %-22s %-14s %s\n" "$SITE" "$STATUS" "$HEALTH"
done

echo ""
echo "  Nginx configs:"
ls -1 "$SERVER/nginx/conf.d/"*.conf 2>/dev/null | while read f; do
    echo "    📄 $(basename "$f")"
done

echo ""
echo "  Docker network:"
docker network inspect server-net --format='    Containers: {{len .Containers}}' 2>/dev/null || echo "    ⚠️ server-net not found"

echo ""
echo "═══════════════════════════════════════════"

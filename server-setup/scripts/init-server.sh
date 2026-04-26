#!/bin/bash
# ═══════════════════════════════════════════════════
# One-time server bootstrap
# Sets up /home/nandha/server/ folder structure and
# tells host Nginx to read configs from our conf.d/
# ═══════════════════════════════════════════════════
set -euo pipefail

SERVER_ROOT="/home/nandha/server"
NGINX_CONF_DIR="$SERVER_ROOT/nginx/conf.d"
SITES_DIR="$SERVER_ROOT/sites"
SCRIPTS_DIR="$SERVER_ROOT/scripts"

echo "🏗️  Creating server folder structure..."
mkdir -p "$NGINX_CONF_DIR" "$SITES_DIR" "$SCRIPTS_DIR"

# Create port registry
if [ ! -f "$SERVER_ROOT/ports.conf" ]; then
    cat > "$SERVER_ROOT/ports.conf" << 'PORTS'
# ─── Port Registry ───
# Each site gets a unique host port.
# Format: PORT  SITE_NAME  STATUS
# ──────────────────────────────────
8081  aidatajakarta  active
# 8082  (next site)  reserved
# 8083  (next site)  reserved
PORTS
    echo "  ✅ ports.conf created"
fi

# Tell host Nginx to include our conf.d directory
INCLUDE_LINE="include $NGINX_CONF_DIR/*.conf;"
NGINX_MAIN="/etc/nginx/nginx.conf"

if grep -qF "$INCLUDE_LINE" "$NGINX_MAIN" 2>/dev/null; then
    echo "  ✅ Nginx already includes our conf.d"
else
    echo ""
    echo "  ⚠️  Add this line inside the 'http { }' block of $NGINX_MAIN :"
    echo ""
    echo "      $INCLUDE_LINE"
    echo ""
    echo "  Or run:"
    echo "      sudo sed -i '/http {/a\\    $INCLUDE_LINE' $NGINX_MAIN"
    echo ""
fi

# Create a README
cat > "$SERVER_ROOT/README.md" << 'README'
# Home Server — Multi-Site Setup

## Folder Structure
```
/home/nandha/server/
├── nginx/
│   └── conf.d/              ← Nginx reads all *.conf here
│       ├── aidatajakarta.conf
│       └── nextsite.conf    (future)
├── sites/
│   ├── aidatajakarta/       ← git clone + docker compose
│   └── nextsite/            (future)
├── scripts/
│   ├── deploy-site.sh       ← deploy/redeploy any site
│   ├── status.sh            ← check all sites
│   └── add-site.sh          ← scaffold a new site
├── ports.conf               ← central port registry
└── README.md
```

## Convention
- Each site is a git repo cloned into `sites/<name>/`
- Each site has its own `docker-compose.yml` + `.env`
- Each site binds to a unique host port (8081, 8082, ...)
- Nginx config for each site in `nginx/conf.d/<name>.conf`
- Ports are tracked in `ports.conf`

## Commands
```bash
# Deploy / redeploy a site
sudo bash scripts/deploy-site.sh aidatajakarta

# Check all sites
sudo bash scripts/status.sh

# Add a new site
sudo bash scripts/add-site.sh mysite https://github.com/user/mysite.git 8082
```
README

echo "✅ Server structure ready at $SERVER_ROOT"

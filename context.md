# Jakarta AI Transport — Project Context

> Last updated: 2026-04-26
> Repo: `https://github.com/chikiball/aidatajakarta.git`
> Local: `/Users/nandha_handharu/Documents/Nandha/GitHub/aidatajakarta`
> Server: `/home/nandha/server/sites/aidatajakarta` (Ubuntu home server)
> Live: **https://jakarta.nandharu.uk**

---

## 1. What This Is

A mobile-friendly web app that predicts daily passenger counts for Jakarta's 8 public transport modes using a neural network. Data is sourced from the Satu Data Jakarta open API and refreshed automatically every day at 02:00 WIB.

---

## 2. Data Source

- **API endpoint:**
  ```
  https://ws.jakarta.go.id/gateway/DataPortalSatuDataJakarta/1.0/satudata?kategori=dataset&tipe=detail&url=jumlah-penumpang-angkutan-umum-yang-terlayani-perhari
  ```
- **Shape:** ~5,365 records, 762 unique dates (2024-01-01 → 2026-01-31)
- **Fields per record:**
  | Field | Example |
  |---|---|
  | `periode_data` | `"202402"` |
  | `tanggal` | `"2024-02-25"` |
  | `jenis_moda` | `"transjakarta"` |
  | `jumlah_penumpang_per_hari` | `"1155322"` (string, may contain commas) |
- **Casing inconsistency:** API returns mixed case (`TRANSJAKARTA`, `transjakarta`). All mode names are normalised to lowercase in code (`parse_int` also strips commas/dots).

---

## 3. Transport Modes (8)

| Key | Label | Icon | Avg passengers/day |
|---|---|---|---|
| `transjakarta` | TransJakarta | 🚌 | ~1,071,648 |
| `krl` | KRL Commuter | 🚆 | ~946,460 |
| `mrt` | MRT Jakarta | 🚇 | ~117,411 |
| `lrt` | LRT Jakarta | 🚈 | ~3,420 |
| `bus sekolah` | Bus Sekolah | 🚍 | ~23,697 |
| `kapal` | Kapal | ⛴️ | ~3,159 |
| `kci commuter bandara` | KCI Bandara | ✈️ | ~6,477 |
| `mikrotrans` | Mikrotrans | 🚐 | ~489,790 (only 31 records) |

---

## 4. File Structure

```
aidatajakarta/
├── app.py                 # Flask app, 7 API routes, APScheduler
├── model.py               # MLPRegressor training, prediction, feature extraction
├── holidays.py            # Indonesian holidays 2024-2026, Ramadan, school holidays
├── templates/
│   └── index.html         # Single-page frontend (4 tabs), Chart.js, Jakarta theme
├── data/                  # (gitignored)
│   └── passenger_data.json  # Cached API response
├── models/                # (gitignored)
│   └── <mode>_model.pkl     # Trained sklearn models + scalers + metrics
├── static/                # (reserved for future assets)
├── server-setup/          # ← deployment configs for self-hosted Ubuntu server
│   ├── docker-compose.yml    # Nginx gateway container definition
│   ├── nginx/
│   │   └── aidatajakarta.conf  # Reverse proxy: proxy_pass http://aidatajakarta:8080
│   └── scripts/
│       ├── init-server.sh    # One-time full server bootstrap
│       ├── deploy-site.sh    # Redeploy any site (pull → build → restart)
│       ├── status.sh         # Dashboard for all running sites
│       └── add-site.sh       # Scaffold a new site with nginx config
├── .github/
│   └── workflows/
│       └── fly-deploy.yml    # GitHub Actions CI for Fly.io
├── requirements.txt       # flask, scikit-learn, numpy, apscheduler, requests, joblib, gunicorn
├── Dockerfile             # python:3.11-slim, gunicorn 2 workers
├── docker-compose.yml     # App container (joins server-net, exposes 8080 internally)
├── fly.toml               # Fly.io config: sin region, 1 GB, auto-stop
├── .dockerignore
├── .gitignore             # ignores data/, models/, __pycache__/
├── README.md
└── context.md             # ← this file
```

---

## 5. Neural Network Details

### Architecture
- **Type:** scikit-learn `MLPRegressor`
- **Layers:** Input(24) → Dense(128, ReLU) → Dense(64, ReLU) → Dense(32, ReLU) → Output(1)
- **Optimizer:** Adam, learning rate 0.001 (adaptive)
- **Regularization:** L2 (α = 0.001)
- **Early stopping:** patience 20 epochs, 15% validation split
- **Train/test split:** 85/15, random_state=42
- **One model per transport mode** (8 separate models)

### 24 Engineered Features

| # | Feature | Category |
|---|---------|----------|
| 1 | `day_of_week` (0–6) | Temporal |
| 2 | `day_of_month` (1–31) | Temporal |
| 3 | `month` (1–12) | Temporal |
| 4 | `week_of_year` (1–53) | Temporal |
| 5 | `quarter` (1–4) | Temporal |
| 6 | `year_normalized` (year − 2024) | Temporal |
| 7 | `is_weekend` | Temporal |
| 8 | `is_monday` | Temporal |
| 9 | `is_friday` | Temporal |
| 10 | `is_public_holiday` | Holiday |
| 11 | `is_religious_holiday` | Holiday |
| 12 | `is_islamic_holiday` | Holiday |
| 13 | `is_ramadan` | Cultural |
| 14 | `is_school_holiday` | Cultural |
| 15 | `days_to_holiday` | Holiday |
| 16 | `is_near_holiday` (≤ 3 days) | Holiday |
| 17 | `is_long_weekend` | Holiday |
| 18 | `payday_proximity` (to 1st/25th) | Economic |
| 19–20 | `sin/cos(day_of_week)` | Cyclical |
| 21–22 | `sin/cos(month)` | Cyclical |
| 23–24 | `sin/cos(day_of_month)` | Cyclical |

### Model Performance (as of 2026-04-26)

| Mode | R² | MAE | Samples |
|---|---|---|---|
| transjakarta | 0.9047 | 55,905 | 762 |
| mrt | 0.7442 | 9,891 | 762 |
| bus sekolah | 0.7385 | 5,424 | 762 |
| kapal | 0.6678 | 745 | 762 |
| mikrotrans | 0.5837 | 67,053 | 31 |
| kci commuter bandara | 0.5492 | 666 | 762 |
| krl | 0.4581 | 91,974 | 762 |
| lrt | 0.2777 | 501 | 762 |

---

## 6. API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | Serves `index.html` |
| GET | `/api/predict?date=YYYY-MM-DD` | Returns predictions for all modes + context |
| GET | `/api/stats` | Aggregate statistics per mode |
| GET | `/api/timeseries` | Daily data per mode for charts |
| GET | `/api/model-info` | Architecture + per-mode metrics |
| GET | `/api/update-status` | Last update time, record count, status |
| POST | `/api/update-now` | Trigger manual data refresh |
| GET | `/api/holidays` | Indonesian public holidays list |

---

## 7. Frontend (Single-Page, 4 Tabs)

| Tab | Content |
|---|---|
| 🎯 **Prediksi** | Date picker → prediction cards (per mode + total), context badges (weekend/holiday/Ramadan/school) |
| 📊 **Data** | Statistics per mode, update status card with manual refresh button |
| 📈 **Grafik** | Time series (monthly avg), doughnut proportion, day-of-week bar chart — all with mode selector tabs |
| 🧠 **AI Model** | NN flow diagram, layer bar chart, feature tag cloud (colour-coded by category), step-by-step explainer, per-model performance cards |

### Design Tokens (mirrors jakarta.go.id)
- Primary red: `#E2231A`
- Navy: `#0F172A` / `#1E3A5F`
- Font: **Plus Jakarta Sans**
- Card radius: 16 px, shadow-md
- Jakarta Monas SVG emblem in header

---

## 8. Daily Update Flow

1. `APScheduler` fires `fetch_and_store_data()` at **19:00 UTC** (= 02:00 WIB).
2. Fetches full dataset from API → saves to `data/passenger_data.json`.
3. Retrains all 8 models → saves `.pkl` files + metrics JSON to `models/`.
4. Updates in-memory `update_status` dict (exposed via `/api/update-status`).
5. Frontend polls status and shows green/yellow/red dot in header.


## 9. Deployment

### 9A. Self-Hosted Ubuntu Server (primary)

- **Server:** Ubuntu home server at `/home/nandha/server/`
- **Domain:** `nandharu.uk` (registered at Cloudflare)
- **Live URL:** https://jakarta.nandharu.uk
- **Architecture:** Cloudflare Tunnel → Nginx → Docker containers (zero exposed ports)

#### Traffic flow

```
Visitor → https://jakarta.nandharu.uk
    │
    ▼
┌──────────────────────────────┐
│  Cloudflare Edge (SIN)       │  HTTPS termination, DDoS, WAF, caching
└──────────┬───────────────────┘
           │  encrypted tunnel (outbound-only from server)
           ▼
┌──────────────────────────────┐
│  cloudflare-tunnel           │  cloudflare/cloudflared:latest
│  network: server-net         │  no host ports
└──────────┬───────────────────┘
           │  http://nginx-gateway:80
           ▼
┌──────────────────────────────┐
│  nginx-gateway               │  nginx:alpine, expose 80 (internal only)
│  network: server-net         │  rate limiting, security headers, bot block
└──────────┬───────────────────┘
           │  http://aidatajakarta:8080
           ▼
┌──────────────────────────────┐
│  aidatajakarta               │  python:3.11-slim, non-root, read-only fs
│  network: server-net         │  expose 8080 (internal only)
│  volumes: app-data,          │  resource limits: 1 GB RAM, 1 CPU
│           app-models         │
└──────────────────────────────┘
```

#### Server folder layout

```
/home/nandha/server/
├── docker-compose.yml          ← nginx-gateway + cloudflare-tunnel
├── .env                        ← CF_TUNNEL_TOKEN (secret, not in git)
├── nginx/
│   ├── nginx.conf              ← Hardened main config
│   ├── conf.d/
│   │   ├── aidatajakarta.conf  ← proxy_pass http://aidatajakarta:8080
│   │   └── <nextsite>.conf     (future sites)
│   └── certs/                  ← reserved for future SSL
├── sites/
│   ├── aidatajakarta/          ← git clone, docker-compose, Dockerfile
│   └── <nextsite>/             (future sites)
├── scripts/
│   ├── deploy-site.sh <name>   ← pull → build → restart → health check
│   ├── status.sh               ← dashboard for all sites
│   └── add-site.sh <n> <r> <p> ← scaffold a new site
└── security/
    └── harden-os.sh            ← UFW + Fail2Ban + SSH hardening
```

#### Key files in this repo

| File | Deployed to | Purpose |
|---|---|---|
| `server-setup/docker-compose.yml` | `/home/nandha/server/` | Nginx + Cloudflare Tunnel containers |
| `server-setup/nginx/nginx.conf` | `nginx/nginx.conf` | Hardened main config (rate limits, headers) |
| `server-setup/nginx/aidatajakarta.conf` | `nginx/conf.d/` | Per-route rate limits, CF real IP |
| `server-setup/security/harden-os.sh` | `security/` | UFW + Fail2Ban + SSH hardening |
| `server-setup/scripts/*.sh` | `scripts/` | deploy, status, add-site management |
| `docker-compose.yml` (repo root) | `sites/aidatajakarta/` | App container (hardened) |
| `Dockerfile` (repo root) | `sites/aidatajakarta/` | Non-root `appuser`, curl for healthcheck |

#### Useful commands

| Task | Command |
|---|---|
| Status dashboard | `sudo bash /home/nandha/server/scripts/status.sh` |
| Redeploy site | `sudo bash /home/nandha/server/scripts/deploy-site.sh aidatajakarta` |
| View app logs | `cd /home/nandha/server/sites/aidatajakarta && sudo docker compose logs -f --tail 50` |
| Restart app | `cd /home/nandha/server/sites/aidatajakarta && sudo docker compose restart` |
| Restart nginx | `sudo docker exec nginx-gateway nginx -s reload` |
| Restart tunnel | `sudo docker restart cloudflare-tunnel` |
| Tunnel logs | `sudo docker logs cloudflare-tunnel --tail 20` |
| Force rebuild | `cd /home/nandha/server/sites/aidatajakarta && sudo docker compose up -d --build --force-recreate` |
| Firewall status | `sudo ufw status verbose` |
| Fail2Ban status | `sudo fail2ban-client status sshd` |

---

### 9B. Security — Defense in Depth (5 Layers)

| Layer | Component | What it does |
|---|---|---|
| **1. Cloudflare** | Edge network | DDoS, WAF, SSL termination, bot management, IP hiding, geo-blocking, caching |
| **2. OS** | UFW + Fail2Ban + SSH | Deny all inbound, SSH from LAN only, 3 failed SSH → 24h ban, root login disabled, auto-updates |
| **3. Nginx** | Rate limits + headers | 10/5/1 req/s by route, security headers, server version hidden, bad bot block, suspicious path block |
| **4. Docker** | Container isolation | Non-root user, read-only fs, no-new-privileges, 1GB/1CPU limits, no host ports, named volumes only |
| **5. App** | Minimal surface | Read-only API, no DB, no uploads, no secrets in code, 7 GET + 1 POST endpoint |

---

### 9C. Cloudflare Tunnel — Full Setup Guide

This is the step-by-step that was used to deploy `jakarta.nandharu.uk` and should be followed for any future site on the same server.

#### Prerequisites

1. **A domain on Cloudflare.** Buy directly from Cloudflare (cheapest: `.xyz` ~$1/yr). Domain Registration → Register Domains. Buying from Cloudflare means nameservers are already set — no migration wait.
2. **Ubuntu server with Docker installed.** The home server at `/home/nandha/server/`.

#### Step 1 — Create a Tunnel (one-time, shared by all sites)

1. Go to **[one.dash.cloudflare.com](https://one.dash.cloudflare.com)** (Zero Trust dashboard)
2. First time: pick a team name → select **Free plan**
3. Sidebar → **Networks** → **Connectors** (previously called "Tunnels")
4. Click **"Create a connector"**
5. Select **Cloudflared** → Next
6. Name it: `home-server` → Save

#### Step 2 — Copy the Tunnel Token

1. On the "Install connector" page, select the **Docker** tab
2. You'll see: `docker run cloudflare/cloudflared ... --token eyJhIjoiNWU...`
3. Copy **only** the token — the `eyJ...` part (very long, 150+ chars)
4. Click Next

**⚠️ Token ≠ Tunnel ID.** The Tunnel ID is a short UUID. The token starts with `eyJ` and is 150+ characters.

#### Step 3 — Add a Public Hostname (one per site)

In the tunnel config, add a hostname:

| Field | Value (for this site) |
|---|---|
| **Subdomain** | `jakarta` |
| **Domain** | `nandharu.uk` |
| **Type** | `HTTP` |
| **URL** | `nginx-gateway:80` |

For future sites, add more hostnames in the same tunnel:

| Field | Value (example) |
|---|---|
| **Subdomain** | `portfolio` |
| **Domain** | `nandharu.uk` |
| **Type** | `HTTP` |
| **URL** | `nginx-gateway:80` |

All sites share the **same tunnel, same token, same nginx-gateway**. Nginx routes by `server_name` in each site's `.conf`.

#### Step 4 — Deploy on the server

**First-time full setup (one command):**
```bash
git clone https://github.com/chikiball/aidatajakarta.git /tmp/setup && \
sudo bash /tmp/setup/server-setup/scripts/init-server.sh YOUR_TUNNEL_TOKEN && \
rm -rf /tmp/setup
```

**If server is already set up (just adding tunnel token):**
```bash
sudo bash -c 'echo "CF_TUNNEL_TOKEN=your-token" > /home/nandha/server/.env'
cd /home/nandha/server && sudo docker compose up -d
```

#### Step 5 — Verify

```bash
# All 3 containers running?
sudo docker ps --format "table {{.Names}}\t{{.Status}}"

# Tunnel connected?  Look for "Connection ... registered"
sudo docker logs cloudflare-tunnel --tail 5

# Full dashboard
sudo bash /home/nandha/server/scripts/status.sh

# HTTP check
curl -sI https://jakarta.nandharu.uk | head -5
```

#### Gotchas encountered during setup

| Issue | Cause | Fix |
|---|---|---|
| `Permission denied` writing `.env` | Server dir owned by root | Use `sudo bash -c 'echo "..." > .env'` |
| `network server-net incorrect label` | Network created by `docker network create` but compose tries to manage it | Set `external: true` in compose `networks:` section |
| `Unauthorized: Invalid tunnel secret` | Token truncated by Docker Compose `.env` interpolation | Put token directly in `docker-compose.yml` environment value instead of using `${CF_TUNNEL_TOKEN}` |
| Cloudflare UI: no "Tunnels" in sidebar | Cloudflare renamed it | Go to **Networks → Connectors** instead |
| Token vs Tunnel ID confusion | Tunnel ID is a short UUID, token starts with `eyJ` | Copy the long `eyJ...` string from the Docker install command |

**Working `docker-compose.yml` pattern for the server gateway** (with token inlined to avoid interpolation issues):

```yaml
services:
  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: cloudflare-tunnel
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=eyJhIjoiYWYy...your-actual-token...SJ9
    networks:
      - server-net
    depends_on:
      - nginx

  nginx:
    image: nginx:alpine
    container_name: nginx-gateway
    restart: unless-stopped
    expose:
      - "80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    networks:
      - server-net

networks:
  server-net:
    external: true
```

---

### 9D. Remote SSH via Cloudflare Tunnel

Secure remote access to the home server from any network — zero open ports, home IP hidden.

#### Traffic flow

```
Your Mac (anywhere)
    │
    ▼  cloudflared access ssh (ProxyCommand)
┌──────────────────────────────┐
│  Cloudflare Edge             │  Zero Trust Access policy (email OTP)
└──────────┬───────────────────┘
           │  encrypted tunnel (outbound-only from server)
           ▼
┌──────────────────────────────┐
│  cloudflare-tunnel           │  extra_hosts: host.docker.internal:host-gateway
│  container on server-net     │
└──────────┬───────────────────┘
           │  host.docker.internal:22
           ▼
┌──────────────────────────────┐
│  sshd on host                │  UFW still denies all inbound — no port 22 exposed
│                              │  SSH key auth required after tunnel auth
└──────────────────────────────┘
```

#### Cloudflare dashboard config

**Public hostname** (in `home-server` tunnel → Public Hostname tab):

| Field | Value |
|---|---|
| Subdomain | `ssh` |
| Domain | `nandharu.uk` |
| Type | `SSH` |
| URL | `host.docker.internal:22` |

**Access policy** (Access → Applications → Self-hosted):

| Field | Value |
|---|---|
| Application name | `SSH Home Server` |
| Subdomain | `ssh` |
| Domain | `nandharu.uk` |
| Policy | Include → Emails → `your-email` |

#### Server-side change

`extra_hosts` added to tunnel service in `/home/nandha/server/docker-compose.yml`:

```yaml
  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: cloudflare-tunnel
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CF_TUNNEL_TOKEN}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - server-net
    depends_on:
      - nginx
```

After changing, restart tunnel: `cd /home/nandha/server && sudo docker compose up -d --force-recreate tunnel`

#### Client-side setup (Mac)

Requires `cloudflared` installed (`brew install cloudflared`).

`~/.ssh/config`:

```ssh-config
Host ssh.nandharu.uk
    HostName ssh.nandharu.uk
    User nandha
    ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
    IdentityFile ~/.ssh/id_rsa
```

Connect: `ssh ssh.nandharu.uk`

First connection opens a browser for Cloudflare Zero Trust email OTP. After auth, SSH session connects through the tunnel.

#### Security layers (3-deep)

| Layer | What |
|---|---|
| **Cloudflare Access** | Email OTP gate — blocks all unauthenticated traffic |
| **Tunnel** | Outbound-only, encrypted — no inbound ports, IP hidden |
| **sshd** | SSH key auth, Fail2Ban (3 attempts → 24h ban), root login disabled |

## 10. Deploying a New Site (Playbook)

Follow this playbook for every new site on the same server.

### Step 1 — Prepare the site repo

The site's `docker-compose.yml` must follow this convention:

```yaml
services:
  app:
    build: .
    container_name: mysitename        # ← unique name, nginx proxies to this
    restart: unless-stopped
    expose:
      - "3000"                        # ← internal port (any number)
    networks:
      - server-net
    # Recommended security hardening:
    read_only: true
    tmpfs: ["/tmp"]
    security_opt: ["no-new-privileges:true"]
    deploy:
      resources:
        limits:
          memory: 1g
          cpus: '1.0'

networks:
  server-net:
    external: true
```

Key rules:
- **`container_name`** must be unique across all sites
- Use **`expose`** (not `ports`) — no host port binding
- Join **`server-net`** as external network
- Add security hardening (read_only, no-new-privileges, resource limits)

### Step 2 — Add nginx config for the site

```bash
sudo tee /home/nandha/server/nginx/conf.d/mysitename.conf << 'NGINX'
server {
    listen 80;
    server_name mysite.nandharu.uk;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    location / {
        limit_req zone=general burst=20 nodelay;
        proxy_pass http://mysitename:3000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $http_cf_connecting_ip;
        proxy_set_header X-Forwarded-For   $http_cf_connecting_ip;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
```

### Step 3 — Add hostname in Cloudflare

1. [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → Networks → Connectors
2. Click your tunnel (`home-server`) → **Public Hostname** tab → **Add a public hostname**
3. Subdomain: `mysite`, Domain: `nandharu.uk`, Type: `HTTP`, URL: `nginx-gateway:80`

### Step 4 — Clone, build, deploy

```bash
# Clone
sudo git clone https://github.com/you/mysite.git /home/nandha/server/sites/mysitename

# Build & start
cd /home/nandha/server/sites/mysitename
sudo docker compose up -d --build

# Reload nginx
sudo docker exec nginx-gateway nginx -s reload

# Verify
curl -sI https://mysite.nandharu.uk | head -5
```

Or use the helper script:
```bash
sudo bash /home/nandha/server/scripts/add-site.sh mysitename https://github.com/you/mysite.git 3000
sudo bash /home/nandha/server/scripts/deploy-site.sh mysitename
```

### Step 5 — Verify all sites

```bash
sudo bash /home/nandha/server/scripts/status.sh
```

### Checklist for new site

- [ ] Repo has `Dockerfile` + `docker-compose.yml` with `server-net` external network
- [ ] `container_name` is unique
- [ ] Uses `expose` (not `ports`)
- [ ] Nginx conf created in `/home/nandha/server/nginx/conf.d/<name>.conf`
- [ ] `server_name` in nginx conf matches the subdomain
- [ ] Public hostname added in Cloudflare tunnel config
- [ ] `nginx -s reload` executed after adding conf
- [ ] Site accessible at `https://<subdomain>.nandharu.uk`

---

## 11. Known Limitations & Future Ideas

- **Mikrotrans** only has 31 data points → low confidence.
- **LRT** narrow range (R² 0.28) → consider separate feature engineering.
- **KRL** high variance / zero outliers → consider filtering.
- Holiday calendar **hardcoded** through 2026 → needs annual extension.
- Consider **Cloudflare Access** for admin endpoints (`/api/update-now`).
- Consider **weather data** as features (rain affects Jakarta commuting).
- Consider **lagged features** (yesterday's count) if real-time data becomes available.
- Token in `docker-compose.yml` is a workaround — Docker Compose `.env` interpolation truncated it. If fixed upstream, move token back to `.env`.

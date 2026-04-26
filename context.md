# Jakarta AI Transport — Project Context

> Last updated: 2026-04-26
> Repo: `https://github.com/chikiball/aidatajakarta.git`
> Local: `/Users/nandha_handharu/Documents/Nandha/GitHub/aidatajakarta`
> Server: `/home/nandha/server/sites/aidatajakarta` (Ubuntu home server)

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

#### Architecture — Cloudflare Tunnel + All-Docker

The server uses a **zero-exposed-ports** architecture. Traffic flows through a Cloudflare Tunnel — an outbound-only encrypted connection from the server to Cloudflare's edge. No router port forwarding is needed and the home IP is never revealed.

```
Internet → Cloudflare Edge (DDoS/WAF/SSL) → cloudflared tunnel → nginx-gateway → app
```

All components run as Docker containers on a shared network (`server-net`).

```
/home/nandha/server/
├── docker-compose.yml          ← nginx-gateway + cloudflare-tunnel containers
├── .env                        ← CF_TUNNEL_TOKEN (secret, not in git)
├── nginx/
│   ├── nginx.conf              ← Hardened main config (rate limits, headers, bot block)
│   ├── conf.d/                 ← Per-site reverse proxy configs
│   │   ├── aidatajakarta.conf
│   │   └── <nextsite>.conf     (future)
│   └── certs/                  ← Reserved for future SSL
├── sites/
│   ├── aidatajakarta/          ← git clone of this repo
│   └── <nextsite>/             (future)
├── scripts/
│   ├── init-server.sh          ← One-time full bootstrap
│   ├── deploy-site.sh <name>   ← Pull → build → restart → health check
│   ├── status.sh               ← Dashboard for all sites
│   └── add-site.sh <n> <r> <p> ← Scaffold a new site
└── security/
    └── harden-os.sh            ← UFW + Fail2Ban + SSH hardening
```

#### How containers connect

```
Internet
    │ (HTTPS, Cloudflare-terminated)
    ▼
┌──────────────────────────────┐
│  Cloudflare Edge             │  DDoS protection, WAF, SSL, caching, geo-block
└──────────┬───────────────────┘
           │ (encrypted tunnel, outbound-only)
           ▼
┌──────────────────────────────┐
│  cloudflare-tunnel           │  (cloudflare/cloudflared:latest)
│  network: server-net         │  No host ports — outbound connection only
└──────────┬───────────────────┘
           │ proxy_pass http://nginx-gateway:80
           ▼
┌──────────────────────────────┐
│  nginx-gateway               │  (nginx:alpine, expose 80 — NO host port)
│  network: server-net         │  Rate limiting, security headers, bot blocking
└──────────┬───────────────────┘
           │ proxy_pass http://aidatajakarta:8080
           ▼
┌──────────────────────────────┐
│  aidatajakarta               │  (python:3.11-slim, non-root, read-only fs)
│  network: server-net         │  expose 8080, no host port
│  volumes: app-data,          │  Resource limits: 1 GB RAM, 1 CPU
│           app-models         │
└──────────────────────────────┘
```

**Key security properties:**
- **Zero host port bindings** — no container exposes ports to the host network.
- Cloudflare Tunnel is **outbound-only** — the server initiates the connection.
- Nginx is only reachable by `cloudflare-tunnel` on the Docker network.
- App container runs as **non-root user**, with **read-only filesystem** and **no-new-privileges**.

#### Key files

| File | Location | Purpose |
|---|---|---|
| `server-setup/docker-compose.yml` | → `/home/nandha/server/` | Nginx gateway + Cloudflare Tunnel + server-net |
| `server-setup/nginx/nginx.conf` | → `nginx/nginx.conf` | Hardened main config (rate limits, headers, bot block) |
| `server-setup/nginx/aidatajakarta.conf` | → `nginx/conf.d/` | Per-route rate limiting, Cloudflare IP forwarding |
| `server-setup/scripts/init-server.sh` | Runs once | Full bootstrap (6 steps including OS hardening) |
| `server-setup/security/harden-os.sh` | Runs once | UFW firewall + Fail2Ban + SSH hardening |
| `docker-compose.yml` (repo root) | Per-site | App container: read-only, non-root, resource-limited |
| `Dockerfile` | Per-site | Non-root `appuser`, curl for healthcheck |

#### First-time setup

```bash
# Without Cloudflare token (LAN-only, add tunnel later):
git clone https://github.com/chikiball/aidatajakarta.git /tmp/setup && \
sudo bash /tmp/setup/server-setup/scripts/init-server.sh && \
rm -rf /tmp/setup

# With Cloudflare token (full public access):
git clone https://github.com/chikiball/aidatajakarta.git /tmp/setup && \
sudo bash /tmp/setup/server-setup/scripts/init-server.sh YOUR_TUNNEL_TOKEN && \
rm -rf /tmp/setup
```

The init script performs 6 steps:
1. Creates `/home/nandha/server/{nginx, sites, scripts, security}`
2. Creates Docker network `server-net`
3. Starts nginx-gateway + cloudflare-tunnel containers
4. Clones repo, builds & starts aidatajakarta container
5. Copies management scripts
6. Runs OS hardening (UFW, Fail2Ban, SSH)

#### Cloudflare Tunnel setup

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com) → Networks → Tunnels
2. Create a tunnel → copy the token
3. In the tunnel config, add a **Public Hostname**:
   - Subdomain: `jakarta` (or whatever you want)
   - Domain: `yourdomain.com`
   - Service: `http://nginx-gateway:80`
4. Pass the token to `init-server.sh` or save it:
   ```bash
   echo 'CF_TUNNEL_TOKEN=your-token' > /home/nandha/server/.env
   cd /home/nandha/server && sudo docker compose up -d
   ```

#### Useful commands

| Task | Command |
|---|---|
| View app logs | `cd /home/nandha/server/sites/aidatajakarta && sudo docker compose logs -f --tail 50` |
| Restart app | `cd /home/nandha/server/sites/aidatajakarta && sudo docker compose restart` |
| Restart nginx | `sudo docker exec nginx-gateway nginx -s reload` |
| Restart tunnel | `sudo docker restart cloudflare-tunnel` |
| Redeploy site | `sudo bash /home/nandha/server/scripts/deploy-site.sh aidatajakarta` |
| Status dashboard | `sudo bash /home/nandha/server/scripts/status.sh` |
| Firewall status | `sudo ufw status verbose` |
| Fail2Ban status | `sudo fail2ban-client status sshd` |

---

### 9B. Security — Defense in Depth (5 Layers)

#### Layer 1: Cloudflare (edge)
- **DDoS protection** — absorbs volumetric attacks at Cloudflare's edge
- **WAF** — blocks SQL injection, XSS, etc.
- **SSL termination** — free HTTPS, visitors never see your server
- **Bot management** — challenge suspicious traffic
- **IP hiding** — home IP never revealed
- **Geo-blocking** — optionally restrict to specific countries
- **Caching** — reduces load for static assets

#### Layer 2: OS Firewall + Fail2Ban (`server-setup/security/harden-os.sh`)

| Component | Config |
|---|---|
| **UFW** | Default deny incoming, allow outgoing. SSH only from LAN (`192.168.0.0/16`). Zero public ports. |
| **Fail2Ban** | SSH: 3 failed attempts → 24h ban. |
| **SSH** | Root login disabled, max 3 auth tries, X11 forwarding off. |
| **Auto-updates** | `unattended-upgrades` for security patches. |

#### Layer 3: Nginx Hardening (`server-setup/nginx/nginx.conf`)

| Protection | Detail |
|---|---|
| **Rate limiting** | General: 10 req/s (burst 20). API: 5 req/s (burst 10). POST update: 1 req/s. |
| **Connection limits** | 30 per IP (general), 10 (API). |
| **Security headers** | X-Frame-Options, X-Content-Type-Options, XSS-Protection, Referrer-Policy, Permissions-Policy |
| **Server hide** | `server_tokens off`. |
| **Bad bot block** | User-agent filter: sqlmap, nikto, nmap, dirbuster, masscan. |
| **Path blocking** | 404 for `.env`, `.git`, `wp-admin`, `.php`, `cgi-bin`. |
| **Request limits** | Max body 1 MB, header limits, 10s timeouts. |
| **Real IP** | Uses `$http_cf_connecting_ip` from Cloudflare. |

#### Layer 4: Docker Isolation (`docker-compose.yml` + `Dockerfile`)

| Protection | Detail |
|---|---|
| **Non-root user** | Runs as `appuser` inside container. |
| **Read-only filesystem** | `read_only: true`. |
| **Writable tmpfs** | Only `/tmp` (in-memory). |
| **No privilege escalation** | `no-new-privileges: true`. |
| **Resource limits** | 1 GB RAM, 1 CPU max. |
| **No host ports** | `expose` only. |
| **Named volumes** | `app-data`, `app-models` are the only writable persistent paths. |

#### Layer 5: Application

| Property | Detail |
|---|---|
| **Read-only API** | No user input stored. No database. No file uploads. |
| **No authentication needed** | Public data only. |
| **Minimal surface** | 7 GET + 1 POST endpoint. |
| **No secrets in code** | Tunnel token in `.env` on server (not in git). |

---

### 9C. Fly.io (alternative / staging)

```bash
fly launch          # first time
fly deploy          # subsequent
```
- Region: **sin** (Singapore), shared CPU, 1 GB RAM
- Force HTTPS, auto-start/stop
- GitHub Actions: `.github/workflows/fly-deploy.yml`

### 9D. Local development

```bash
pip install -r requirements.txt
python app.py       # → http://localhost:8080
```

---

## 10. Known Limitations & Future Ideas

- **Mikrotrans** only has 31 data points → low confidence.
- **LRT** narrow range (R² 0.28) → consider separate feature engineering.
- **KRL** high variance / zero outliers → consider filtering.
- Holiday calendar **hardcoded** through 2026 → needs annual extension.
- Consider **Cloudflare Access** for admin endpoints (`/api/update-now`).
- Consider **weather data** as features (rain affects Jakarta commuting).
- Consider **lagged features** (yesterday's count) if real-time data becomes available.

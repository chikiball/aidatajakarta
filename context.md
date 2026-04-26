# Jakarta AI Transport — Project Context

> Last updated: 2026-04-26
> Repo: `/Users/nandha_handharu/Documents/Nandha/GitHub/aidatajakarta`
> Remote: `origin/main` on GitHub

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
├── data/
│   └── passenger_data.json  # Cached API response (gitignored)
├── models/
│   └── <mode>_model.pkl     # Trained sklearn models + scalers (gitignored)
├── static/                # (empty, reserved for future assets)
├── requirements.txt       # flask, scikit-learn, numpy, apscheduler, requests, joblib, gunicorn
├── Dockerfile             # python:3.11-slim, gunicorn 2 workers
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

---

## 9. Deployment

### Fly.io
```bash
fly launch          # first time — creates app 'aidatajakarta' in sin region
fly deploy          # subsequent deploys
```
- Region: **sin** (Singapore)
- VM: shared CPU, 1 GB RAM
- Port: 8080, force HTTPS, auto-start/stop

### Local
```bash
pip install -r requirements.txt
python app.py       # → http://localhost:8080
```

---

## 10. Known Limitations & Future Ideas

- **Mikrotrans** only has 31 data points → low confidence. Will improve as daily updates accumulate.
- **LRT** has narrow passenger range (1,450–8,345) → model underfits (R² 0.28). Consider separate feature engineering.
- **KRL** has high variance and zero-value outliers → could benefit from outlier filtering.
- Holiday calendar is **hardcoded** through 2026. Needs annual extension or dynamic source.
- No persistent volume on Fly.io — `data/` and `models/` are rebuilt on each deploy/restart (acceptable since auto-fetch runs on startup).
- Consider adding **Fly.io volume** or **SQLite** for persistence across restarts.
- Consider **weather data** as additional features (rain strongly affects Jakarta commuting).
- Consider **lagged features** (yesterday's passenger count) if real-time data becomes available.

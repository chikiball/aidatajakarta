# Jakarta AI Transport — Prediksi Penumpang Angkutan Umum

🏙️ AI-powered passenger prediction for Jakarta's public transportation system.

## Features

- **Neural Network Predictions**: MLP (128→64→32) predicts daily passengers for 8 transport modes
- **24 Engineered Features**: Temporal, calendar, Indonesian holidays, Ramadan, school holidays, cyclical encoding
- **Real-time Data**: Daily updates from [Satu Data Jakarta](https://data.jakarta.go.id)
- **Mobile-First UI**: Jakarta-themed responsive design with card-style layout
- **Interactive Charts**: Time series, pie charts, day-of-week analysis
- **AI Explainability**: Visual infographic of how the neural network makes predictions

## Transport Modes

🚌 TransJakarta • 🚆 KRL Commuter • 🚇 MRT • 🚈 LRT • 🚍 Bus Sekolah • ⛴️ Kapal • ✈️ KCI Bandara • 🚐 Mikrotrans

## Tech Stack

- **Backend**: Python Flask + Gunicorn
- **ML**: scikit-learn MLPRegressor
- **Frontend**: Vanilla HTML/CSS/JS + Chart.js
- **Deployment**: Fly.io (Singapore region)
- **Scheduler**: APScheduler (daily data refresh at 02:00 WIB)

## Deploy

```bash
fly launch
fly deploy
```

## Local Development

```bash
pip install -r requirements.txt
python app.py
```

## Data Source

[Satu Data Jakarta API](https://ws.jakarta.go.id/gateway/DataPortalSatuDataJakarta/1.0/satudata?kategori=dataset&tipe=detail&url=jumlah-penumpang-angkutan-umum-yang-terlayani-perhari)

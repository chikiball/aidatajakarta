"""
Flask application for Jakarta AI Public Transport Prediction.
"""
import json
import os
import logging
from datetime import date, datetime, timedelta
from threading import Thread

import requests
from flask import Flask, jsonify, render_template, request
from apscheduler.schedulers.background import BackgroundScheduler

from model import (
    train_all_models, predict_all_modes, get_model_info,
    load_data, TRANSPORT_MODES, TRANSPORT_LABELS, TRANSPORT_ICONS,
    FEATURE_NAMES, parse_int
)
from holidays import (
    HOLIDAYS, is_public_holiday, get_holiday_name,
    is_ramadan, is_school_holiday
)

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
API_URL = "https://ws.jakarta.go.id/gateway/DataPortalSatuDataJakarta/1.0/satudata?kategori=dataset&tipe=detail&url=jumlah-penumpang-angkutan-umum-yang-terlayani-perhari"

# App state
update_status = {
    'last_update': None,
    'last_status': 'never',
    'records_count': 0,
    'next_update': None,
    'is_updating': False,
}


def fetch_and_store_data():
    """Fetch data from Jakarta API and store locally."""
    update_status['is_updating'] = True
    try:
        logger.info("Fetching data from Jakarta API...")
        resp = requests.get(API_URL, timeout=30)
        resp.raise_for_status()
        raw = resp.json()
        data = raw.get('data', [])

        if not data:
            update_status['last_status'] = 'error: empty response'
            return False

        os.makedirs(DATA_DIR, exist_ok=True)
        with open(os.path.join(DATA_DIR, 'passenger_data.json'), 'w') as f:
            json.dump(data, f)

        update_status['last_update'] = datetime.now().isoformat()
        update_status['last_status'] = 'success'
        update_status['records_count'] = len(data)

        logger.info(f"Stored {len(data)} records. Training models...")
        train_all_models(data)
        logger.info("Models trained successfully.")
        return True

    except Exception as e:
        logger.error(f"Data fetch failed: {e}")
        update_status['last_status'] = f'error: {str(e)}'
        return False
    finally:
        update_status['is_updating'] = False


def get_data_statistics():
    """Compute statistics from stored data."""
    data = load_data()
    if not data:
        return None

    stats = {}
    dates = sorted(set(r['tanggal'] for r in data))

    for mode in TRANSPORT_MODES:
        vals = []
        daily = {}
        for r in data:
            if r['jenis_moda'].lower().strip() == mode:
                v = parse_int(r['jumlah_penumpang_per_hari'])
                vals.append(v)
                daily[r['tanggal']] = v

        if vals:
            stats[mode] = {
                'label': TRANSPORT_LABELS.get(mode, mode),
                'icon': TRANSPORT_ICONS.get(mode, '🚍'),
                'total': sum(vals),
                'avg': int(sum(vals) / len(vals)),
                'min': min(vals),
                'max': max(vals),
                'count': len(vals),
                'daily': daily,
            }

    return {
        'modes': stats,
        'date_range': {'start': dates[0], 'end': dates[-1]},
        'total_records': len(data),
        'unique_dates': len(dates),
    }


def get_time_series_data():
    """Get time-series data for charts."""
    data = load_data()
    if not data:
        return None

    # Aggregate by date and mode
    series = {}
    for mode in TRANSPORT_MODES:
        daily = {}
        for r in data:
            if r['jenis_moda'].lower().strip() == mode:
                daily[r['tanggal']] = parse_int(r['jumlah_penumpang_per_hari'])
        if daily:
            series[mode] = {
                'label': TRANSPORT_LABELS.get(mode, mode),
                'icon': TRANSPORT_ICONS.get(mode, '🚍'),
                'data': [{'date': d, 'value': daily[d]} for d in sorted(daily.keys())]
            }

    return series


# ─── Routes ───

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/predict', methods=['GET'])
def api_predict():
    """Predict passengers for a given date."""
    date_str = request.args.get('date')
    if not date_str:
        date_str = date.today().isoformat()

    try:
        target = date.fromisoformat(date_str)
    except ValueError:
        return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400

    predictions = predict_all_modes(target)
    if not predictions:
        return jsonify({'error': 'Models not trained yet'}), 503

    # Add contextual info
    context = {
        'date': date_str,
        'day_name': target.strftime('%A'),
        'is_weekend': target.weekday() >= 5,
        'is_holiday': is_public_holiday(target),
        'holiday_name': get_holiday_name(target),
        'is_ramadan': is_ramadan(target),
        'is_school_holiday': is_school_holiday(target),
    }

    return jsonify({
        'predictions': predictions,
        'context': context,
        'total_predicted': sum(p['predicted_passengers'] for p in predictions.values()),
    })


@app.route('/api/stats')
def api_stats():
    """Get data statistics."""
    stats = get_data_statistics()
    if not stats:
        return jsonify({'error': 'No data available'}), 503
    return jsonify(stats)


@app.route('/api/timeseries')
def api_timeseries():
    """Get time-series data for charts."""
    series = get_time_series_data()
    if not series:
        return jsonify({'error': 'No data available'}), 503
    return jsonify(series)


@app.route('/api/model-info')
def api_model_info():
    """Get model training info."""
    info = get_model_info()
    return jsonify({
        'models': info,
        'feature_names': FEATURE_NAMES,
        'architecture': {
            'type': 'Multi-Layer Perceptron (Neural Network)',
            'layers': [len(FEATURE_NAMES), 128, 64, 32, 1],
            'activation': 'ReLU',
            'optimizer': 'Adam',
            'regularization': 'L2 (α=0.001)',
            'early_stopping': True,
            'feature_engineering': [
                'Temporal: day of week, day of month, month, week of year, quarter',
                'Calendar: weekend, Monday, Friday flags',
                'Holidays: public, religious, Islamic holidays',
                'Cultural: Ramadan period, school holidays',
                'Proximity: days to nearest holiday, near-holiday flag',
                'Economic: payday proximity, long weekend detection',
                'Cyclical: sin/cos encoding for day, month periodicity',
            ]
        }
    })


@app.route('/api/update-status')
def api_update_status():
    """Get data update status."""
    return jsonify(update_status)


@app.route('/api/update-now', methods=['POST'])
def api_update_now():
    """Trigger manual data update."""
    if update_status['is_updating']:
        return jsonify({'status': 'already updating'}), 409
    thread = Thread(target=fetch_and_store_data)
    thread.start()
    return jsonify({'status': 'update started'})


@app.route('/api/holidays')
def api_holidays():
    """Get Indonesian public holidays."""
    holidays_list = []
    for d, (name, is_rel, is_islam) in sorted(HOLIDAYS.items()):
        holidays_list.append({
            'date': d.isoformat(),
            'name': name,
            'is_religious': is_rel,
            'is_islamic': is_islam,
        })
    return jsonify(holidays_list)


# ─── Startup ───

def init_app():
    """Initialize: fetch data and train models on first run."""
    if not os.path.exists(os.path.join(DATA_DIR, 'passenger_data.json')):
        logger.info("No cached data found. Fetching from API...")
        fetch_and_store_data()
    else:
        logger.info("Cached data found.")
        update_status['last_status'] = 'cached'
        data = load_data()
        if data:
            update_status['records_count'] = len(data)
            # Check if models exist
            from model import MODEL_DIR
            if not os.path.exists(os.path.join(MODEL_DIR, 'transjakarta_model.pkl')):
                logger.info("Training models from cached data...")
                train_all_models(data)


# Schedule daily updates at 2:00 AM WIB (UTC+7 = 19:00 UTC previous day)
scheduler = BackgroundScheduler()
scheduler.add_job(fetch_and_store_data, 'cron', hour=19, minute=0, id='daily_update')
scheduler.start()
update_status['next_update'] = 'Daily at 02:00 WIB'

# Init on startup
init_thread = Thread(target=init_app)
init_thread.start()


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)

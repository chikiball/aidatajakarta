"""
Neural Network Model for Jakarta Public Transport Passenger Prediction.
Uses scikit-learn MLPRegressor with rich feature engineering.
"""
import json
import os
import logging
from datetime import date, datetime, timedelta
import numpy as np
from sklearn.neural_network import MLPRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib

from holidays import (
    is_public_holiday, is_religious_holiday, is_islamic_holiday,
    is_ramadan, is_school_holiday, days_to_nearest_holiday,
    is_near_holiday, is_long_weekend, get_payday_proximity
)

logger = logging.getLogger(__name__)

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
MODEL_DIR = os.path.join(os.path.dirname(__file__), 'models')

TRANSPORT_MODES = [
    'transjakarta', 'krl', 'mrt', 'lrt',
    'bus sekolah', 'kapal', 'kci commuter bandara', 'mikrotrans'
]

TRANSPORT_LABELS = {
    'transjakarta': 'TransJakarta',
    'krl': 'KRL Commuter',
    'mrt': 'MRT Jakarta',
    'lrt': 'LRT Jakarta',
    'bus sekolah': 'Bus Sekolah',
    'kapal': 'Kapal',
    'kci commuter bandara': 'KCI Bandara',
    'mikrotrans': 'Mikrotrans'
}

TRANSPORT_ICONS = {
    'transjakarta': '🚌',
    'krl': '🚆',
    'mrt': '🚇',
    'lrt': '🚈',
    'bus sekolah': '🚍',
    'kapal': '⛴️',
    'kci commuter bandara': '✈️',
    'mikrotrans': '🚐'
}

FEATURE_NAMES = [
    'day_of_week',       # 0-6 (Mon-Sun)
    'day_of_month',      # 1-31
    'month',             # 1-12
    'week_of_year',      # 1-53
    'quarter',           # 1-4
    'year_normalized',   # Year - 2024
    'is_weekend',        # 0/1
    'is_monday',         # 0/1
    'is_friday',         # 0/1
    'is_public_holiday', # 0/1
    'is_religious_holiday', # 0/1
    'is_islamic_holiday',   # 0/1
    'is_ramadan',        # 0/1
    'is_school_holiday', # 0/1
    'days_to_holiday',   # int
    'is_near_holiday',   # 0/1
    'is_long_weekend',   # 0/1
    'payday_proximity',  # int
    'sin_day_of_week',   # cyclical encoding
    'cos_day_of_week',
    'sin_month',
    'cos_month',
    'sin_day_of_month',
    'cos_day_of_month',
]


def extract_features(d: date) -> np.ndarray:
    """Extract feature vector from a date."""
    dow = d.weekday()
    dom = d.day
    month = d.month
    woy = d.isocalendar()[1]
    quarter = (month - 1) // 3 + 1

    features = [
        dow,
        dom,
        month,
        woy,
        quarter,
        d.year - 2024,
        1 if dow >= 5 else 0,
        1 if dow == 0 else 0,
        1 if dow == 4 else 0,
        1 if is_public_holiday(d) else 0,
        1 if is_religious_holiday(d) else 0,
        1 if is_islamic_holiday(d) else 0,
        1 if is_ramadan(d) else 0,
        1 if is_school_holiday(d) else 0,
        days_to_nearest_holiday(d),
        1 if is_near_holiday(d) else 0,
        1 if is_long_weekend(d) else 0,
        get_payday_proximity(d),
        np.sin(2 * np.pi * dow / 7),
        np.cos(2 * np.pi * dow / 7),
        np.sin(2 * np.pi * month / 12),
        np.cos(2 * np.pi * month / 12),
        np.sin(2 * np.pi * dom / 31),
        np.cos(2 * np.pi * dom / 31),
    ]
    return np.array(features, dtype=np.float64)


def load_data():
    """Load cached data from disk."""
    path = os.path.join(DATA_DIR, 'passenger_data.json')
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return None


def parse_int(val):
    """Parse integer from potentially comma/dot-separated string."""
    if isinstance(val, (int, float)):
        return int(val)
    return int(str(val).replace(',', '').replace('.', '').strip() or '0')


def prepare_training_data(raw_data, mode):
    """Prepare X, y arrays for a specific transport mode."""
    X, y = [], []
    mode_lower = mode.lower().strip()
    for record in raw_data:
        if record['jenis_moda'].lower().strip() == mode_lower:
            try:
                d = date.fromisoformat(record['tanggal'])
                passengers = parse_int(record['jumlah_penumpang_per_hari'])
                if passengers > 0:
                    X.append(extract_features(d))
                    y.append(passengers)
            except (ValueError, KeyError):
                continue
    return np.array(X), np.array(y)


def train_model(mode, raw_data=None):
    """Train a neural network model for a specific transport mode."""
    if raw_data is None:
        cached = load_data()
        if cached is None:
            raise ValueError("No data available for training")
        raw_data = cached

    X, y = prepare_training_data(raw_data, mode)
    if len(X) < 30:
        logger.warning(f"Not enough data for {mode}: {len(X)} samples")
        return None

    # Scale features and target
    scaler_X = StandardScaler()
    scaler_y = StandardScaler()

    X_scaled = scaler_X.fit_transform(X)
    y_scaled = scaler_y.fit_transform(y.reshape(-1, 1)).ravel()

    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y_scaled, test_size=0.15, random_state=42
    )

    model = MLPRegressor(
        hidden_layer_sizes=(128, 64, 32),
        activation='relu',
        solver='adam',
        max_iter=1000,
        early_stopping=True,
        validation_fraction=0.15,
        n_iter_no_change=20,
        random_state=42,
        learning_rate='adaptive',
        learning_rate_init=0.001,
        alpha=0.001,  # L2 regularization
    )

    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    y_pred_real = scaler_y.inverse_transform(y_pred.reshape(-1, 1)).ravel()
    y_test_real = scaler_y.inverse_transform(y_test.reshape(-1, 1)).ravel()

    mae = mean_absolute_error(y_test_real, y_pred_real)
    r2 = r2_score(y_test_real, y_pred_real)

    logger.info(f"Model {mode}: MAE={mae:.0f}, R²={r2:.4f}, samples={len(X)}")

    # Save model, scalers, and metrics
    os.makedirs(MODEL_DIR, exist_ok=True)
    mode_slug = mode.replace(' ', '_')
    joblib.dump(model, os.path.join(MODEL_DIR, f'{mode_slug}_model.pkl'))
    joblib.dump(scaler_X, os.path.join(MODEL_DIR, f'{mode_slug}_scaler_X.pkl'))
    joblib.dump(scaler_y, os.path.join(MODEL_DIR, f'{mode_slug}_scaler_y.pkl'))

    metrics = {
        'mode': mode,
        'mae': float(mae),
        'r2': float(r2),
        'samples': int(len(X)),
        'trained_at': datetime.now().isoformat(),
        'feature_count': len(FEATURE_NAMES),
        'architecture': '128-64-32',
    }
    with open(os.path.join(MODEL_DIR, f'{mode_slug}_metrics.json'), 'w') as f:
        json.dump(metrics, f, indent=2)

    return metrics


def train_all_models(raw_data=None):
    """Train models for all transport modes."""
    results = {}
    if raw_data is None:
        cached = load_data()
        if cached is None:
            raise ValueError("No data available")
        raw_data = cached

    for mode in TRANSPORT_MODES:
        try:
            metrics = train_model(mode, raw_data)
            if metrics:
                results[mode] = metrics
        except Exception as e:
            logger.error(f"Failed to train {mode}: {e}")
            results[mode] = {'error': str(e)}
    return results


def predict(mode, target_date):
    """Predict passenger count for a mode and date."""
    mode_slug = mode.lower().strip().replace(' ', '_')
    model_path = os.path.join(MODEL_DIR, f'{mode_slug}_model.pkl')
    scaler_x_path = os.path.join(MODEL_DIR, f'{mode_slug}_scaler_X.pkl')
    scaler_y_path = os.path.join(MODEL_DIR, f'{mode_slug}_scaler_y.pkl')

    if not all(os.path.exists(p) for p in [model_path, scaler_x_path, scaler_y_path]):
        return None

    model = joblib.load(model_path)
    scaler_X = joblib.load(scaler_x_path)
    scaler_y = joblib.load(scaler_y_path)

    if isinstance(target_date, str):
        target_date = date.fromisoformat(target_date)

    features = extract_features(target_date).reshape(1, -1)
    features_scaled = scaler_X.transform(features)
    prediction_scaled = model.predict(features_scaled)
    prediction = scaler_y.inverse_transform(prediction_scaled.reshape(-1, 1)).ravel()[0]

    return max(0, int(round(prediction)))


def predict_all_modes(target_date):
    """Predict for all transport modes."""
    if isinstance(target_date, str):
        target_date = date.fromisoformat(target_date)

    results = {}
    for mode in TRANSPORT_MODES:
        pred = predict(mode, target_date)
        if pred is not None:
            # Load metrics
            mode_slug = mode.replace(' ', '_')
            metrics_path = os.path.join(MODEL_DIR, f'{mode_slug}_metrics.json')
            metrics = {}
            if os.path.exists(metrics_path):
                with open(metrics_path) as f:
                    metrics = json.load(f)

            results[mode] = {
                'predicted_passengers': pred,
                'label': TRANSPORT_LABELS.get(mode, mode),
                'icon': TRANSPORT_ICONS.get(mode, '🚍'),
                'confidence': metrics.get('r2', 0),
                'mae': metrics.get('mae', 0),
            }
    return results


def get_model_info():
    """Get info about all trained models."""
    info = {}
    for mode in TRANSPORT_MODES:
        mode_slug = mode.replace(' ', '_')
        metrics_path = os.path.join(MODEL_DIR, f'{mode_slug}_metrics.json')
        if os.path.exists(metrics_path):
            with open(metrics_path) as f:
                info[mode] = json.load(f)
    return info

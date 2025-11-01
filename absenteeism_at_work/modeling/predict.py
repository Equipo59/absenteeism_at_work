"""
Prediction module for absenteeism model.

This module provides functionality to:
- Load trained models
- Make predictions on new data
- Evaluate predictions (if ground truth available)
- Export predictions
"""

import os
import json
import argparse
import joblib
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

from ..config import PROCESSED_DATA_PATH

MODELS_DIR = Path("models")
REPORTS_DIR = Path("reports/metrics")
TARGET_COLUMN = 'Absenteeism time in hours'


def load_model(model_path=None):
    """Load trained model from disk."""
    if model_path is None:
        # Try to load best model
        best_model_path = MODELS_DIR / "best_model.joblib"
        if best_model_path.exists():
            model_path = best_model_path
        else:
            # List available models
            available_models = list(MODELS_DIR.glob("*_model.joblib"))
            if not available_models:
                raise FileNotFoundError(
                    f"No trained models found in {MODELS_DIR}. "
                    "Please train a model first using: python -m absenteeism_at_work.modeling.train"
                )
            model_path = available_models[0]
            print(f"⚠️  Using first available model: {model_path.name}")
    
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")
    
    model = joblib.load(model_path)
    print(f"✅ Loaded model from: {model_path}")
    return model


def load_data(data_path, has_target=True):
    """Load data for prediction."""
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"Data file not found: {data_path}")
    
    df = pd.read_csv(data_path)
    print(f"✅ Loaded data: {df.shape[0]} rows, {df.shape[1]} columns")
    
    if has_target and TARGET_COLUMN in df.columns:
        X = df.drop(columns=[TARGET_COLUMN])
        y = df[TARGET_COLUMN]
        return X, y, True
    elif has_target:
        print(f"⚠️  Target column '{TARGET_COLUMN}' not found. Making predictions only.")
        return df, None, False
    
    return df, None, False


def predict(model, X):
    """Make predictions using the trained model."""
    print(f"🔮 Making predictions for {len(X)} samples...")
    
    predictions = model.predict(X)
    
    # Ensure predictions are non-negative (absenteeism hours can't be negative)
    predictions = np.maximum(predictions, 0)
    
    print(f"✅ Predictions completed")
    print(f"   Min: {predictions.min():.2f} hours")
    print(f"   Max: {predictions.max():.2f} hours")
    print(f"   Mean: {predictions.mean():.2f} hours")
    
    return predictions


def evaluate_predictions(y_true, y_pred):
    """Evaluate predictions against ground truth."""
    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    r2 = r2_score(y_true, y_pred)
    
    metrics = {
        'mae': float(mae),
        'rmse': float(rmse),
        'r2': float(r2)
    }
    
    print("\n📊 Evaluation Metrics:")
    print(f"   MAE:  {mae:.3f} hours")
    print(f"   RMSE: {rmse:.3f} hours")
    print(f"   R²:   {r2:.3f}")
    
    return metrics


def save_predictions(predictions, X, output_path=None):
    """Save predictions to CSV file."""
    if output_path is None:
        output_path = REPORTS_DIR / "predictions.csv"
    
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Create results dataframe
    results_df = X.copy()
    results_df['predicted_absenteeism_hours'] = predictions
    
    results_df.to_csv(output_path, index=False)
    print(f"💾 Predictions saved to: {output_path}")
    
    return output_path


def save_evaluation_metrics(metrics, output_path=None):
    """Save evaluation metrics to JSON."""
    if output_path is None:
        output_path = REPORTS_DIR / "evaluation_metrics.json"
    
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w') as f:
        json.dump(metrics, f, indent=2)
    
    print(f"📈 Metrics saved to: {output_path}")


def main():
    """Main prediction function."""
    parser = argparse.ArgumentParser(description='Make predictions with trained absenteeism model')
    parser.add_argument('--data', type=str, default=PROCESSED_DATA_PATH,
                        help='Path to input data CSV file')
    parser.add_argument('--model', type=str, default=None,
                        help='Path to trained model file (default: models/best_model.joblib)')
    parser.add_argument('--output', type=str, default=None,
                        help='Path to save predictions CSV')
    parser.add_argument('--evaluate', action='store_true',
                        help='Evaluate predictions if ground truth available')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🔮 Starting Prediction Pipeline")
    print("=" * 60)
    
    # Load model
    model = load_model(args.model)
    
    # Load data
    if args.evaluate:
        X, y, has_target = load_data(args.data, has_target=True)
    else:
        data = pd.read_csv(args.data)
        if TARGET_COLUMN in data.columns:
            X = data.drop(columns=[TARGET_COLUMN])
            y = data[TARGET_COLUMN] if args.evaluate else None
            has_target = True
        else:
            X = data
            y = None
            has_target = False
    
    # Make predictions
    predictions = predict(model, X)
    
    # Evaluate if requested and target available
    if args.evaluate and has_target and y is not None:
        metrics = evaluate_predictions(y, predictions)
        save_evaluation_metrics(metrics)
    
    # Save predictions
    save_predictions(predictions, X, args.output)
    
    print("\n" + "=" * 60)
    print("✅ Prediction pipeline completed")
    print("=" * 60)
    
    return predictions


if __name__ == "__main__":
    main()


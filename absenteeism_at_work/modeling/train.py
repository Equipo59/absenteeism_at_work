"""
Training module for absenteeism prediction model.

This module implements a complete ML training pipeline with:
- Data loading and splitting
- Feature preprocessing (numeric + categorical)
- Model training (RandomForest, LightGBM, CatBoost)
- Model evaluation and metrics
- MLflow integration for experiment tracking
- Model persistence
"""

import os
import json
import joblib
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import mlflow
import mlflow.sklearn
from mlflow.models import infer_signature

# Relative imports
from ..config import PROCESSED_DATA_PATH

# Optional imports for advanced models
try:
    from lightgbm import LGBMRegressor
    LIGHTGBM_AVAILABLE = True
except ImportError:
    LIGHTGBM_AVAILABLE = False
    print("⚠️  LightGBM not available. Install with: pip install lightgbm")

try:
    from catboost import CatBoostRegressor
    CATBOOST_AVAILABLE = True
except ImportError:
    CATBOOST_AVAILABLE = False
    print("⚠️  CatBoost not available. Install with: pip install catboost")


# Configuration
RANDOM_STATE = 42
TEST_SIZE = 0.2
TARGET_COLUMN = 'Absenteeism time in hours'
MODELS_DIR = Path("models")
REPORTS_DIR = Path("reports/metrics")
MLRUNS_DIR = Path("mlruns")


def ensure_directories():
    """Create necessary directories if they don't exist."""
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    MLRUNS_DIR.mkdir(parents=True, exist_ok=True)


def load_data(data_path=PROCESSED_DATA_PATH):
    """Load processed dataset."""
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"Data file not found: {data_path}")
    
    df = pd.read_csv(data_path)
    print(f"✅ Loaded dataset: {df.shape[0]} rows, {df.shape[1]} columns")
    return df


def prepare_features(df, target_col=TARGET_COLUMN):
    """
    Prepare features and target, identify categorical and numeric columns.
    
    Returns:
        X: Feature dataframe
        y: Target series
        categorical_cols: List of categorical column names
        numeric_cols: List of numeric column names
    """
    if target_col not in df.columns:
        raise ValueError(f"Target column '{target_col}' not found in data")
    
    # Remove duplicates
    df = df.drop_duplicates().copy()
    
    # Split features and target
    X = df.drop(columns=[target_col])
    y = df[target_col]
    
    # Identify categorical columns (those that should be treated as categories)
    # Even if they're numeric, some columns represent categories
    categorical_candidates = [
        'Reason for absence', 'Month of absence', 'Day of the week', 
        'Seasons', 'Education', 'Disciplinary failure', 
        'Social drinker', 'Social smoker'
    ]
    
    categorical_cols = [c for c in categorical_candidates if c in X.columns]
    numeric_cols = [c for c in X.columns if c not in categorical_cols]
    
    # Ensure categorical columns are treated as such
    for col in categorical_cols:
        X[col] = X[col].astype('category')
    
    print(f"📊 Features: {len(numeric_cols)} numeric, {len(categorical_cols)} categorical")
    print(f"   Numeric: {numeric_cols[:3]}..." if len(numeric_cols) > 3 else f"   Numeric: {numeric_cols}")
    print(f"   Categorical: {categorical_cols}")
    
    return X, y, categorical_cols, numeric_cols


def create_preprocessor(numeric_cols, categorical_cols):
    """Create preprocessing pipeline with ColumnTransformer."""
    numeric_transformer = Pipeline([
        ('scaler', StandardScaler())
    ])
    
    categorical_transformer = Pipeline([
        ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False))
    ])
    
    preprocessor = ColumnTransformer(
        transformers=[
            ('num', numeric_transformer, numeric_cols),
            ('cat', categorical_transformer, categorical_cols)
        ],
        remainder='drop'
    )
    
    return preprocessor


def train_model(name, model, preprocessor, X_train, X_test, y_train, y_test):
    """
    Train a model and evaluate it.
    
    Returns:
        dict with model name, metrics, and trained pipeline
    """
    print(f"\n🤖 Training {name}...")
    
    # Create full pipeline
    full_pipeline = Pipeline([
        ('preprocessor', preprocessor),
        ('model', model)
    ])
    
    # Train
    full_pipeline.fit(X_train, y_train)
    
    # Predict
    y_pred_train = full_pipeline.predict(X_train)
    y_pred_test = full_pipeline.predict(X_test)
    
    # Calculate metrics
    metrics = {
        'train_mae': mean_absolute_error(y_train, y_pred_train),
        'train_rmse': np.sqrt(mean_squared_error(y_train, y_pred_train)),
        'train_r2': r2_score(y_train, y_pred_train),
        'test_mae': mean_absolute_error(y_test, y_pred_test),
        'test_rmse': np.sqrt(mean_squared_error(y_test, y_pred_test)),
        'test_r2': r2_score(y_test, y_pred_test),
    }
    
    print(f"   Train - MAE: {metrics['train_mae']:.3f}, RMSE: {metrics['train_rmse']:.3f}, R²: {metrics['train_r2']:.3f}")
    print(f"   Test  - MAE: {metrics['test_mae']:.3f}, RMSE: {metrics['test_rmse']:.3f}, R²: {metrics['test_r2']:.3f}")
    
    return {
        'name': name,
        'metrics': metrics,
        'pipeline': full_pipeline,
        'model': model
    }


def save_model(model_result, models_dir=MODELS_DIR):
    """Save trained model to disk."""
    model_name = model_result['name'].lower().replace(' ', '_')
    model_path = models_dir / f"{model_name}_model.joblib"
    
    joblib.dump(model_result['pipeline'], model_path)
    print(f"💾 Model saved to: {model_path}")
    
    return model_path


def log_to_mlflow(model_result, model_path, X_train, y_train):
    """Log model and metrics to MLflow."""
    try:
        # Set MLflow tracking URI (local by default)
        mlflow.set_tracking_uri(f"file://{MLRUNS_DIR.resolve()}")
        mlflow.set_experiment("absenteeism_prediction")
        
        with mlflow.start_run(run_name=model_result['name']):
            # Log parameters
            if hasattr(model_result['model'], 'get_params'):
                mlflow.log_params(model_result['model'].get_params())
            
            # Log metrics
            mlflow.log_metrics(model_result['metrics'])
            
            # Infer signature
            signature = infer_signature(X_train.head(100), y_train.head(100))
            
            # Log model
            mlflow.sklearn.log_model(
                model_result['pipeline'],
                artifact_path="model",
                signature=signature,
                registered_model_name=f"absenteeism_{model_result['name'].lower().replace(' ', '_')}"
            )
            
            # Log model path
            mlflow.log_artifact(str(model_path))
            
            print(f"📊 Logged to MLflow: {mlflow.get_tracking_uri()}")
            
    except Exception as e:
        print(f"⚠️  MLflow logging failed: {e}")


def save_metrics(results, reports_dir=REPORTS_DIR):
    """Save training metrics to JSON file."""
    metrics_data = {
        'models': [
            {
                'name': r['name'],
                'metrics': r['metrics']
            }
            for r in results
        ]
    }
    
    metrics_path = reports_dir / "training_metrics.json"
    with open(metrics_path, 'w') as f:
        json.dump(metrics_data, f, indent=2)
    
    print(f"📈 Metrics saved to: {metrics_path}")


def main():
    """Main training function."""
    print("=" * 60)
    print("🚀 Starting Model Training Pipeline")
    print("=" * 60)
    
    # Setup
    ensure_directories()
    
    # Load data
    df = load_data()
    
    # Prepare features
    X, y, cat_cols, num_cols = prepare_features(df)
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE
    )
    print(f"📊 Data split - Train: {X_train.shape}, Test: {X_test.shape}")
    
    # Create preprocessor
    preprocessor = create_preprocessor(num_cols, cat_cols)
    
    # Initialize models
    models = [
        ("RandomForest", RandomForestRegressor(
            n_estimators=500,
            max_depth=10,
            min_samples_split=5,
            random_state=RANDOM_STATE,
            n_jobs=-1
        ))
    ]
    
    if LIGHTGBM_AVAILABLE:
        models.append((
            "LightGBM",
            LGBMRegressor(
                n_estimators=500,
                learning_rate=0.05,
                max_depth=8,
                random_state=RANDOM_STATE,
                verbose=-1
            )
        ))
    
    if CATBOOST_AVAILABLE:
        models.append((
            "CatBoost",
            CatBoostRegressor(
                iterations=500,
                learning_rate=0.05,
                depth=8,
                random_state=RANDOM_STATE,
                verbose=False
            )
        ))
    
    # Train models
    results = []
    best_model = None
    best_score = float('inf')
    
    for name, model in models:
        result = train_model(name, model, preprocessor, X_train, X_test, y_train, y_test)
        results.append(result)
        
        # Track best model (by test RMSE)
        if result['metrics']['test_rmse'] < best_score:
            best_score = result['metrics']['test_rmse']
            best_model = result
    
        # Save model
        model_path = save_model(result)
        
        # Log to MLflow
        log_to_mlflow(result, model_path, X_train, y_train)
    
    # Save metrics
    save_metrics(results)
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Training Summary")
    print("=" * 60)
    print(f"Best Model: {best_model['name']}")
    print(f"  Test RMSE: {best_model['metrics']['test_rmse']:.3f}")
    print(f"  Test R²: {best_model['metrics']['test_r2']:.3f}")
    print("=" * 60)
    
    # Save best model as default
    best_model_path = MODELS_DIR / "best_model.joblib"
    joblib.dump(best_model['pipeline'], best_model_path)
    print(f"💾 Best model saved to: {best_model_path}")
    
    return results


if __name__ == "__main__":
    main()


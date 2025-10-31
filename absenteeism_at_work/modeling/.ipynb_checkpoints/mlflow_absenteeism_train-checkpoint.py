"""
Entrenamiento y tracking con MLflow para Absenteeism at Work.

Uso (ejemplos desde la raíz del proyecto):
  py absenteeism_at_work\modeling\mlflow_absenteeism_train.py --model linear --test_size 0.2
  py absenteeism_at_work\modeling\mlflow_absenteeism_train.py --model random_forest --n_estimators 300 --max_depth 12 --test_size 0.25
  py absenteeism_at_work\modeling\mlflow_absenteeism_train.py --model xgboost --xgb_learning_rate 0.05 --xgb_n_estimators 400

Requisitos:
  - mlflow instalado
  - scikit-learn
  - (opcional) xgboost si usas --model xgboost
"""

import argparse
import os
import warnings
warnings.filterwarnings("ignore")

import mlflow
import mlflow.sklearn
import numpy as np
import pandas as pd

from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor

# =========================
# 1) Argumentos CLI
# =========================
def parse_args():
    p = argparse.ArgumentParser(description="Train absenteeism models with MLflow tracking.")
    # datos
    p.add_argument("--data_path", type=str, default="data/raw/work_absenteeism_raw.csv",
                   help="Ruta al CSV de datos (crudo o limpio).")
    p.add_argument("--target", type=str, default="Absenteeism time in hours",
                   help="Nombre de la columna objetivo.")
    p.add_argument("--test_size", type=float, default=0.20, help="Proporción de test.")
    p.add_argument("--random_state", type=int, default=42, help="Semilla aleatoria.")

    # experimento
    p.add_argument("--experiment", type=str, default="absenteeism_tuning",
                   help="Nombre del experimento en MLflow.")

    # modelo
    p.add_argument("--model", type=str, default="linear",
                   choices=["linear", "random_forest", "xgboost"],
                   help="Tipo de modelo a entrenar.")

    # hiperparámetros RandomForest
    p.add_argument("--n_estimators", type=int, default=200)
    p.add_argument("--max_depth", type=int, default=None)

    # hiperparámetros XGBoost (si se usa)
    p.add_argument("--xgb_learning_rate", type=float, default=0.1)
    p.add_argument("--xgb_n_estimators", type=int, default=300)

    return p.parse_args()

args = parse_args()


# =========================
# 2) Utilidades
# =========================
def load_dataframe(path: str) -> pd.DataFrame:
    """Lee CSV y trata '?' como NaN; no rompe si el archivo trae basura."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"No se encontró el archivo de datos: {path}")
    df = pd.read_csv(path, na_values=["?"])
    # Normaliza espacios en nombres de columnas
    df.columns = [c.strip() for c in df.columns]
    return df


def coerce_numeric(df: pd.DataFrame, target: str) -> pd.DataFrame:
    """
    Convierte todas las columnas (excepto target) a numérico (errores -> NaN).
    Convierte target a numérico (errores -> NaN) y rellena con 0 por simplicidad.
    """
    for col in df.columns:
        if col == target:
            continue
        df[col] = pd.to_numeric(df[col], errors="coerce")
    # target
    df[target] = pd.to_numeric(df[target], errors="coerce")
    return df


def basic_clean(df: pd.DataFrame, target: str) -> pd.DataFrame:
    """Limpieza mínima: drop de columnas irrelevantes típicas, fillna simple."""
    # Borra columnas comunes si existen
    df = df.drop(columns=["ID"], errors="ignore")

    # Rellena NaN: numéricas con mediana; categóricas (si hubiera) con moda.
    num_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    cat_cols = [c for c in df.columns if c not in num_cols]

    if num_cols:
        df[num_cols] = df[num_cols].fillna(df[num_cols].median())
    for c in cat_cols:
        df[c] = df[c].fillna(df[c].mode().iloc[0] if not df[c].mode().empty else "Unknown")

    # Asegura que target no tenga NaN (simple: 0). Ajusta a necesidad.
    if df[target].isna().any():
        df[target] = df[target].fillna(0)

    return df


def make_model(args):
    """Devuelve el estimador según args.model y sus hiperparámetros."""
    if args.model == "linear":
        return LinearRegression()

    if args.model == "random_forest":
        return RandomForestRegressor(
            n_estimators=args.n_estimators,
            max_depth=args.max_depth,
            random_state=args.random_state
        )

    if args.model == "xgboost":
        try:
            from xgboost import XGBRegressor
        except Exception as e:
            raise RuntimeError(
                "Para usar --model xgboost instala el paquete: pip install xgboost"
            ) from e
        return XGBRegressor(
            learning_rate=args.xgb_learning_rate,
            n_estimators=args.xgb_n_estimators,
            random_state=args.random_state,
            tree_method="hist"
        )

    raise ValueError(f"Modelo no soportado: {args.model}")


def train_and_log(df: pd.DataFrame, args):
    """Entrena, evalúa y loguea en MLflow parámetros, métricas y el modelo."""
    target = args.target
    if target not in df.columns:
        raise KeyError(f"No se encontró la columna objetivo '{target}' en el dataset.")

    X = df.drop(columns=[target])
    y = df[target]

    # Split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size, random_state=args.random_state
    )

    # ===== MLflow setup =====
    mlflow.set_tracking_uri("file:./mlruns")
    mlflow.set_experiment(args.experiment)

    with mlflow.start_run(run_name=f"{args.model}_run") as run:
        # Log de parámetros comunes
        mlflow.log_param("model_type", args.model)
        mlflow.log_param("test_size", args.test_size)
        mlflow.log_param("random_state", args.random_state)
        mlflow.log_param("n_features", X_train.shape[1])

        # Log de hiperparámetros específicos
        if args.model == "random_forest":
            mlflow.log_param("n_estimators", args.n_estimators)
            mlflow.log_param("max_depth", args.max_depth)
        if args.model == "xgboost":
            mlflow.log_param("xgb_learning_rate", args.xgb_learning_rate)
            mlflow.log_param("xgb_n_estimators", args.xgb_n_estimators)

        # Modelo
        model = make_model(args)
        model.fit(X_train, y_train)

        # Eval
        y_pred = model.predict(X_test)
        mae = mean_absolute_error(y_test, y_pred)
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)
        r2 = r2_score(y_test, y_pred)

        # Log métricas
        mlflow.log_metric("MAE", float(mae))
        mlflow.log_metric("MSE", float(mse))
        mlflow.log_metric("RMSE", float(rmse))
        mlflow.log_metric("R2", float(r2))

        # Firma y ejemplo de entrada para evitar warnings
        # (tomamos una fila del X_test como ejemplo)
        input_example = X_test.iloc[:1]
        try:
            from mlflow.models.signature import infer_signature
            signature = infer_signature(X_test, y_pred)
        except Exception:
            signature = None

        # Log del modelo al registry
        # Nota: a partir de MLflow 3.5, 'artifact_path' se renombró a 'name' en algunas APIs;
        # mlflow.sklearn.log_model mantiene compatibilidad.
        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
            registered_model_name="absenteeism_regression",
            signature=signature,
            input_example=input_example
        )

        print(f"✅ Entrenamiento completado | "
              f"Modelo: {args.model} | "
              f"MAE={mae:.2f} | RMSE={rmse:.2f} | R2={r2:.2f}")


# =========================
# 3) Main
# =========================
def main():
    # Carga
    df = load_dataframe(args.data_path)
    print(f"✅ Dataset cargado: {df.shape[0]} registros y {df.shape[1]} columnas")

    # Coerción numérica robusta (incluye target)
    df = coerce_numeric(df, args.target)

    # Limpieza básica
    df = basic_clean(df, args.target)

    # Entrena + MLflow
    train_and_log(df, args)


if __name__ == "__main__":
    main()
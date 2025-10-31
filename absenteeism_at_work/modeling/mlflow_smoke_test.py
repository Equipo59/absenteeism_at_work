import mlflow

# 1) Carpeta local donde se guardarán los experimentos
mlflow.set_tracking_uri("file:./mlruns")

# 2) Crear o usar el experimento "absenteeism_baseline"
mlflow.set_experiment("absenteeism_baseline")

# 3) Iniciar un run de prueba
with mlflow.start_run(run_name="smoke-test"):
    # Registrar parámetros
    mlflow.log_param("model", "baseline_dummy")
    mlflow.log_param("n_features", 20)
    mlflow.log_param("preprocessing", "clean+winsorize")

    # Registrar métricas
    mlflow.log_metric("mae", 12.34)
    mlflow.log_metric("rmse", 18.90)
    mlflow.log_metric("r2", 0.42)

print("✅ MLflow: experimento y run registrados correctamente.")
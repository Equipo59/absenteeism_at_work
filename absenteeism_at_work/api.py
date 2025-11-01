"""
FastAPI application for serving the absenteeism prediction model.

This API provides endpoints to:
- Health check
- Make single predictions
- Make batch predictions
- Get model information
- Serve static HTML frontend
"""

import os
import joblib
from pathlib import Path
from typing import List, Optional
import pandas as pd
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field
import uvicorn

from absenteeism_at_work.config import PROCESSED_DATA_PATH

# Model paths
MODELS_DIR = Path("models")
DEFAULT_MODEL = MODELS_DIR / "best_model.joblib"

# Initialize FastAPI app
app = FastAPI(
    title="Absenteeism Prediction API",
    description="API for predicting employee absenteeism hours",
    version="1.0.0"
)

# CORS middleware - Only allow same origin (frontend and API on same server)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Same origin, so this is safe
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files (CSS, JS)
static_path = Path(__file__).parent / "static"
if static_path.exists():
    app.mount("/static", StaticFiles(directory=str(static_path)), name="static")

# Global model variable
model = None


# Pydantic models for request/response
class AbsenteeismInput(BaseModel):
    """Input features for a single prediction."""
    reason_for_absence: int = Field(..., ge=0, le=28, description="Reason for absence (0-28)")
    month_of_absence: int = Field(..., ge=0, le=12, description="Month of absence (0-12)")
    day_of_the_week: int = Field(..., ge=2, le=6, description="Day of week (2-6, Mon-Fri)")
    seasons: int = Field(..., ge=1, le=4, description="Season (1-4)")
    transportation_expense: float = Field(..., ge=0, description="Transportation expense")
    distance_from_residence_to_work: float = Field(..., ge=0, description="Distance in km")
    service_time: float = Field(..., ge=0, description="Service time in years")
    age: int = Field(..., ge=0, description="Age")
    work_load_average_per_day: float = Field(..., ge=0, description="Work load average per day")
    hit_target: int = Field(..., ge=0, le=100, description="Hit target (0-100)")
    disciplinary_failure: int = Field(..., ge=0, le=1, description="Disciplinary failure (0/1)")
    education: int = Field(..., ge=1, le=4, description="Education level (1-4)")
    son: int = Field(..., ge=0, description="Number of sons")
    social_drinker: int = Field(..., ge=0, le=1, description="Social drinker (0/1)")
    social_smoker: int = Field(..., ge=0, le=1, description="Social smoker (0/1)")
    pet: int = Field(..., ge=0, description="Number of pets")
    weight: float = Field(..., ge=0, description="Weight in kg")
    height: float = Field(..., ge=0, description="Height in cm")
    body_mass_index: float = Field(..., ge=0, description="Body mass index")
    
    class Config:
        json_schema_extra = {
            "example": {
                "reason_for_absence": 23,
                "month_of_absence": 7,
                "day_of_the_week": 3,
                "seasons": 1,
                "transportation_expense": 289,
                "distance_from_residence_to_work": 36,
                "service_time": 13,
                "age": 33,
                "work_load_average_per_day": 240,
                "hit_target": 97,
                "disciplinary_failure": 0,
                "education": 1,
                "son": 2,
                "social_drinker": 1,
                "social_smoker": 0,
                "pet": 1,
                "weight": 90,
                "height": 172,
                "body_mass_index": 30
            }
        }


class PredictionResponse(BaseModel):
    """Response model for prediction."""
    predicted_absenteeism_hours: float = Field(..., description="Predicted absenteeism hours")
    model_version: Optional[str] = Field(None, description="Model version/name")


class BatchPredictionRequest(BaseModel):
    """Request model for batch predictions."""
    inputs: List[AbsenteeismInput] = Field(..., description="List of input features")


class BatchPredictionResponse(BaseModel):
    """Response model for batch predictions."""
    predictions: List[PredictionResponse] = Field(..., description="List of predictions")
    total: int = Field(..., description="Total number of predictions")


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    model_loaded: bool


class ModelInfoResponse(BaseModel):
    """Model information response."""
    model_path: str
    model_type: str
    features: List[str]


def load_model(model_path: Optional[Path] = None):
    """Load the trained model."""
    global model
    
    if model_path is None:
        model_path = DEFAULT_MODEL
    
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found at {model_path}")
    
    loaded_model = joblib.load(model_path)
    model = loaded_model
    print(f"✅ Model loaded from: {model_path}")
    return loaded_model


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    global model
    try:
        if DEFAULT_MODEL.exists():
            load_model()
            print("✅ Model loaded successfully")
        else:
            print(f"⚠️  Model not found at {DEFAULT_MODEL}. Please train a model first.")
            model = None
    except Exception as e:
        print(f"⚠️  Error loading model: {e}")
        print(f"💡 Tip: The model may have been trained with a different scikit-learn version.")
        print(f"   Try retraining the model with: make train")
        model = None


def input_to_dataframe(input_data: AbsenteeismInput) -> pd.DataFrame:
    """Convert Pydantic input to pandas DataFrame."""
    data = {
        'Reason for absence': [input_data.reason_for_absence],
        'Month of absence': [input_data.month_of_absence],
        'Day of the week': [input_data.day_of_the_week],
        'Seasons': [input_data.seasons],
        'Transportation expense': [input_data.transportation_expense],
        'Distance from Residence to Work': [input_data.distance_from_residence_to_work],
        'Service time': [input_data.service_time],
        'Age': [input_data.age],
        'Work load Average/day': [input_data.work_load_average_per_day],
        'Hit target': [input_data.hit_target],
        'Disciplinary failure': [input_data.disciplinary_failure],
        'Education': [input_data.education],
        'Son': [input_data.son],
        'Social drinker': [input_data.social_drinker],
        'Social smoker': [input_data.social_smoker],
        'Pet': [input_data.pet],
        'Weight': [input_data.weight],
        'Height': [input_data.height],
        'Body mass index': [input_data.body_mass_index]
    }
    return pd.DataFrame(data)


@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve the HTML frontend page."""
    html_path = Path(__file__).parent / "static" / "index.html"
    if html_path.exists():
        return FileResponse(html_path)
    else:
        # Fallback if HTML not found
        return HTMLResponse(content="""
        <html>
            <head><title>Absenteeism API</title></head>
            <body>
                <h1>Absenteeism Prediction API</h1>
                <p><a href="/docs">API Documentation</a></p>
                <p><a href="/health">Health Check</a></p>
            </body>
        </html>
        """)


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy" if model is not None else "model_not_loaded",
        "model_loaded": model is not None
    }


@app.get("/info", response_model=ModelInfoResponse)
async def model_info():
    """Get model information."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Try to get feature names from the pipeline
    try:
        if hasattr(model, 'named_steps') and 'preprocessor' in model.named_steps:
            preprocessor = model.named_steps['preprocessor']
            feature_names = []
            for name, transformer, columns in preprocessor.transformers_:
                if hasattr(columns, '__iter__') and not isinstance(columns, str):
                    feature_names.extend(columns)
                else:
                    feature_names.append(columns)
        else:
            feature_names = ["Unknown - model structure not accessible"]
    except:
        feature_names = ["Unable to extract feature names"]
    
    return {
        "model_path": str(DEFAULT_MODEL),
        "model_type": type(model).__name__,
        "features": feature_names
    }


@app.post("/predict", response_model=PredictionResponse)
async def predict(input_data: AbsenteeismInput):
    """Make a single prediction."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please train a model first.")
    
    try:
        # Convert input to DataFrame
        df = input_to_dataframe(input_data)
        
        # Make prediction
        prediction = model.predict(df)
        
        # Ensure non-negative
        prediction = max(0, float(prediction[0]))
        
        return {
            "predicted_absenteeism_hours": round(prediction, 2),
            "model_version": DEFAULT_MODEL.stem if DEFAULT_MODEL.exists() else None
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Prediction error: {str(e)}")


@app.post("/predict/batch", response_model=BatchPredictionResponse)
async def predict_batch(batch_request: BatchPredictionRequest):
    """Make batch predictions."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please train a model first.")
    
    try:
        # Convert all inputs to DataFrame
        dfs = [input_to_dataframe(input_data) for input_data in batch_request.inputs]
        df = pd.concat(dfs, ignore_index=True)
        
        # Make predictions
        predictions = model.predict(df)
        
        # Ensure non-negative
        predictions = np.maximum(predictions, 0)
        
        return {
            "predictions": [
                {
                    "predicted_absenteeism_hours": round(float(pred), 2),
                    "model_version": DEFAULT_MODEL.stem if DEFAULT_MODEL.exists() else None
                }
                for pred in predictions
            ],
            "total": len(predictions)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Batch prediction error: {str(e)}")


def main():
    """Run the API server."""
    import uvicorn
    uvicorn.run("absenteeism_at_work.api:app", host="0.0.0.0", port=8000, reload=True)


if __name__ == "__main__":
    main()


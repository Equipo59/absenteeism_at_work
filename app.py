"""
Main entry point for the FastAPI application.

Run with: uvicorn app:app --reload
Or: python app.py
"""

from absenteeism_at_work.api import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)


# Multi-stage Dockerfile for Absenteeism Prediction API

# Stage 1: Build stage
FROM python:3.10-slim as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Install optional ML dependencies if needed
RUN pip install --no-cache-dir --user lightgbm catboost || true

# Stage 2: Runtime stage
FROM python:3.10-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY absenteeism_at_work/ ./absenteeism_at_work/
COPY app.py .
COPY pyproject.toml .

# Ensure static directory exists
RUN mkdir -p absenteeism_at_work/static

# Create necessary directories
RUN mkdir -p models data/processed reports/metrics mlruns

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Run the API
CMD ["python", "app.py"]


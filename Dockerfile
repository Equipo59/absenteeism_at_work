# Multi-stage Dockerfile for Absenteeism Prediction API (Optimized)

# Stage 1: Build stage
FROM python:3.10-slim as builder

WORKDIR /app

# Install only essential build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy only API requirements
COPY requirements-api.txt .

# Install Python dependencies without cache
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --user -r requirements-api.txt

# Stage 2: Runtime stage
FROM python:3.10-slim

WORKDIR /app

# Install only runtime dependencies (no build tools needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Copy only necessary application code
COPY absenteeism_at_work/ ./absenteeism_at_work/
COPY app.py .

# Ensure static directory exists
RUN mkdir -p absenteeism_at_work/static

# Create necessary directories
RUN mkdir -p models data/processed reports/metrics mlruns

# Expose API port
EXPOSE 8000

# Health check (using curl instead of Python requests)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the API
CMD ["python", "app.py"]

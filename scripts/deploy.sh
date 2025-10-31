#!/bin/bash

echo "🚀 Starting deployment process..."

# Check deployment mode
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"local"}
echo "📦 Deployment mode: $DEPLOYMENT_MODE"

# Ensure Docker is running
echo "🔧 Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not installed"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo "🔧 Starting Docker..."
    sudo systemctl start docker || true
fi

# Stop existing containers gracefully
echo "🛑 Stopping existing containers..."
cd "$(dirname "$0")/.." || cd ~/absenteeism_at_work
sudo docker-compose down || true
sudo docker stop $(sudo docker ps -q --filter ancestor=absenteeism-api:latest) 2>/dev/null || true

# Ensure we're in the right directory
pwd
ls -la

# Build Docker image
echo "🐳 Building Docker image..."
sudo docker build -t absenteeism-api:latest . || {
    echo "❌ Docker build failed"
    exit 1
}

# Start containers with docker-compose
echo "🚀 Starting application with docker-compose..."
sudo docker-compose up -d || {
    echo "❌ Failed to start containers"
    exit 1
}

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
sleep 15
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -f http://localhost:8000/health &>/dev/null; then
        echo "✅ API is healthy!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: API not ready yet..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️ API did not become healthy after $max_attempts attempts"
    echo "Checking logs..."
    sudo docker-compose logs --tail=50
    exit 1
fi

echo "✅ Deployment completed successfully!"
echo "🌐 API URL: http://localhost:8000"
echo "📚 Docs: http://localhost:8000/docs"
echo "📊 MLflow: http://localhost:5001"


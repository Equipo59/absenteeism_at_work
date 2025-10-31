#!/bin/bash
set -e

echo "🚀 Starting deployment process..."

# Check deployment mode
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"local"}
echo "📦 Deployment mode: $DEPLOYMENT_MODE"

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "🔧 Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER || true
fi

# Ensure user is in docker group
if ! groups | grep -q docker; then
    echo "⚠️ Current user not in docker group. You may need to log out and back in."
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
sudo docker-compose down || true
sudo docker stop $(sudo docker ps -q --filter ancestor=absenteeism-api:latest) 2>/dev/null || true

# Pull latest code (if in git repo)
if [ -d .git ]; then
    echo "📥 Pulling latest code..."
    git pull origin web || git pull origin main || true
fi

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
if [ -d venv ]; then
    source venv/bin/activate || true
else
    python3 -m venv venv || true
    source venv/bin/activate || true
fi

pip install --upgrade pip
pip install -e .

# Preprocess data if needed
if [ ! -f "data/processed/work_absenteeism_processed.csv" ]; then
    echo "🔄 Preprocessing data..."
    python -m absenteeism_at_work.preprocess_data || true
fi

# Train model if no best model exists
if [ ! -f "models/best_model.joblib" ]; then
    echo "🤖 Training model..."
    python -m absenteeism_at_work.modeling.train || true
fi

# Build Docker image
echo "🐳 Building Docker image..."
sudo docker build -t absenteeism-api:latest .

# Start containers with docker-compose
echo "🚀 Starting application with docker-compose..."
sudo docker-compose up -d

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
sleep 10
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


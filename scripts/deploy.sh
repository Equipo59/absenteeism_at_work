#!/bin/bash
# Deployment script for EC2 instance
# This script:
# 1. Sets up Python environment and dependencies
# 2. Preprocesses data if needed
# 3. Trains the model if needed
# 4. Sets up Docker and Docker Compose
# 5. Builds and deploys the API in a Docker container

set -e

echo "🚀 Starting deployment..."
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Please do not run as root. This script will use sudo when needed."
    exit 1
fi

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# ==========================================
# STEP 1: Python Environment Setup
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 STEP 1: Setting up Python environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "✅ Python version: $PYTHON_VERSION"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip -q || true

# Install Python dependencies
echo "📦 Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -q -r requirements.txt || {
        echo "❌ Failed to install requirements.txt"
        exit 1
    }
else
    echo "⚠️  requirements.txt not found"
fi

if [ -f "requirements-api.txt" ]; then
    pip install -q -r requirements-api.txt || {
        echo "⚠️  Failed to install requirements-api.txt, installing basic packages..."
        pip install -q fastapi uvicorn pydantic numpy pandas scikit-learn joblib
    }
else
    echo "📦 Installing basic API dependencies..."
    pip install -q fastapi uvicorn pydantic numpy pandas scikit-learn joblib
fi

echo "✅ Python environment ready"
echo ""

# ==========================================
# STEP 2: Data Preprocessing
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 STEP 2: Preprocessing data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "data/processed/work_absenteeism_processed.csv" ]; then
    if [ ! -f "data/raw/work_absenteeism_raw.csv" ]; then
        echo "❌ Error: Raw data file not found at data/raw/work_absenteeism_raw.csv"
        exit 1
    fi
    echo "📊 Preprocessing data..."
    python -m absenteeism_at_work.preprocess_data || {
        echo "❌ Data preprocessing failed"
        exit 1
    }
    echo "✅ Data preprocessing completed"
else
    echo "✅ Processed data already exists"
fi
echo ""

# ==========================================
# STEP 3: Model Training
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 STEP 3: Training model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "models/best_model.joblib" ]; then
    echo "🤖 Training model (model not found)..."
    python -m absenteeism_at_work.modeling.train || {
        echo "❌ Model training failed"
        exit 1
    }
    echo "✅ Model training completed"
elif [ "data/processed/work_absenteeism_processed.csv" -nt "models/best_model.joblib" ]; then
    echo "🔄 Data is newer than model, retraining..."
    python -m absenteeism_at_work.modeling.train || {
        echo "⚠️  Model retraining failed, using existing model"
    }
    echo "✅ Model updated"
else
    echo "✅ Model already exists and is up to date"
fi

# Verify model exists
if [ ! -f "models/best_model.joblib" ]; then
    echo "❌ Error: Model training failed. models/best_model.joblib not found."
    exit 1
fi

MODEL_SIZE=$(du -h models/best_model.joblib | cut -f1)
echo "✅ Model ready (Size: $MODEL_SIZE)"
echo ""

# ==========================================
# STEP 4: Docker Setup
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 STEP 4: Setting up Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update system packages (Linux only)
if [ "$OS" == "linux" ]; then
    echo "📦 Updating system packages..."
    sudo apt-get update -q && sudo apt-get upgrade -y -q || {
        echo "⚠️  Package update failed, continuing..."
    }
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    if [ "$OS" == "linux" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        echo "⚠️  Docker group changes require logout/login or run: newgrp docker"
        # Try to activate docker group for current session
        newgrp docker <<EOF || true
echo "Docker group activated"
EOF
    else
        echo "❌ Docker installation not automated for macOS."
        echo "   Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
else
    DOCKER_VERSION=$(docker --version)
    echo "✅ Docker already installed: $DOCKER_VERSION"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "🔧 Installing Docker Compose..."
    if [ "$OS" == "linux" ]; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "❌ Docker Compose installation not automated for macOS."
        echo "   Docker Compose comes with Docker Desktop"
        exit 1
    fi
else
    COMPOSE_VERSION=$(docker-compose --version)
    echo "✅ Docker Compose already installed: $COMPOSE_VERSION"
fi

# Verify Docker is working
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running or user doesn't have permissions"
    echo "   Try: sudo systemctl start docker (Linux)"
    echo "   Or: Start Docker Desktop (macOS)"
    exit 1
fi
echo ""

# ==========================================
# STEP 5: Docker Deployment
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 STEP 5: Deploying API with Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop existing containers if running
echo "🛑 Stopping existing containers (if any)..."
docker-compose down 2>/dev/null || true

# Verify required files exist
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

# Build and start containers
echo "🏗️  Building Docker image..."
docker-compose build --no-cache || {
    echo "❌ Docker build failed"
    echo "📋 Checking build logs..."
    docker-compose logs 2>&1 | tail -50
    exit 1
}

echo "🚀 Starting containers..."
docker-compose up -d || {
    echo "❌ Failed to start containers"
    echo "📋 Checking logs..."
    docker-compose logs --tail=50
    exit 1
}

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ API is responding!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 2
done

# Final health check
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verifying deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -f -s http://localhost:8000/health | grep -q "healthy\|model_loaded"; then
    HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
    echo "✅ Health check passed"
    echo "   Response: $HEALTH_RESPONSE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Deployment completed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 API Endpoints:"
    echo "   • API Base:      http://localhost:8000"
    echo "   • Frontend:      http://localhost:8000/"
    echo "   • Health Check:  http://localhost:8000/health"
    echo "   • API Docs:      http://localhost:8000/docs"
    echo "   • ReDoc:         http://localhost:8000/redoc"
    echo ""
    echo "📊 MLflow UI:"
    echo "   • MLflow UI:     http://localhost:5000"
    echo ""
    echo "📋 Useful Commands:"
    echo "   • View logs:    docker-compose logs -f"
    echo "   • Stop API:      docker-compose down"
    echo "   • Restart API:   docker-compose restart"
    echo "   • Check status:  docker-compose ps"
    echo ""
    
    # Get container info
    if [ "$OS" == "linux" ]; then
        EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
        if [ -n "$EC2_IP" ]; then
            echo "🌐 External Access:"
            echo "   • http://$EC2_IP:8000"
            echo "   • http://$EC2_IP:8000/docs"
        else
            # Try to get IP from AWS metadata or hostname
            HOSTNAME=$(hostname -f 2>/dev/null || hostname)
            echo "🌐 Access this instance at:"
            echo "   • http://$HOSTNAME:8000"
            echo "   • http://$HOSTNAME:8000/docs"
        fi
    fi
else
    echo "❌ API health check failed after $MAX_ATTEMPTS attempts"
    echo ""
    echo "📋 Container status:"
    docker-compose ps
    echo ""
    echo "📋 Recent logs:"
    docker-compose logs --tail=50
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check if port 8000 is available: netstat -tuln | grep 8000"
    echo "   2. View full logs: docker-compose logs"
    echo "   3. Check container: docker ps -a"
    exit 1
fi


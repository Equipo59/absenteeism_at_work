#!/bin/bash
# Deployment script - Aligned with GitHub Actions workflow
# Supports both local and remote (EC2) deployment modes

set -e

echo "🚀 Starting deployment..."
echo ""

# ==========================================
# Load Environment Variables
# ==========================================
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env..."
    set -a
    source .env
    set +a
else
    echo "⚠️  .env file not found. Using defaults or environment variables."
    echo "   Create .env from .env.example if needed."
fi

# Set defaults if not provided
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-local}
AWS_REGION=${AWS_REGION:-us-east-1}
EC2_INSTANCE_TYPE=${EC2_INSTANCE_TYPE:-t3.micro}
DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-absenteeism-api}
EC2_USER=${EC2_USER:-ubuntu}
SKIP_INFRASTRUCTURE=${SKIP_INFRASTRUCTURE:-false}
SKIP_DOCKER_BUILD=${SKIP_DOCKER_BUILD:-false}

echo "🔧 Deployment Mode: $DEPLOYMENT_MODE"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Please do not run as root. This script will use sudo when needed."
    exit 1
fi

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    IS_EC2=false
    # Check if running on EC2
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        IS_EC2=true
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    IS_EC2=false
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
pip install --no-cache-dir --upgrade pip -q || true

# Install Python dependencies (matching GitHub Actions)
echo "📦 Installing Python dependencies..."
pip install --no-cache-dir -r requirements.txt || {
    echo "❌ Failed to install requirements.txt"
    exit 1
}

pip install --no-cache-dir -r requirements-api.txt || {
    echo "⚠️  Installing basic API packages..."
    pip install --no-cache-dir fastapi uvicorn pydantic numpy pandas scikit-learn joblib
}

# Install AWS CLI and boto3 if deploying remotely
if [ "$DEPLOYMENT_MODE" == "remote" ]; then
    echo "📦 Installing AWS CLI and boto3..."
    pip install --no-cache-dir boto3 awscli || true
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

if [ ! -f "models/best_model.joblib" ]; then
    echo "❌ Error: Model training failed. models/best_model.joblib not found."
    exit 1
fi

MODEL_SIZE=$(du -h models/best_model.joblib | cut -f1)
echo "✅ Model ready (Size: $MODEL_SIZE)"
echo ""

# ==========================================
# STEP 4: AWS Infrastructure (Remote Mode Only)
# ==========================================
if [ "$DEPLOYMENT_MODE" == "remote" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "☁️  STEP 4: Setting up AWS Infrastructure"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Configure AWS credentials
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "❌ AWS credentials not found in .env"
        echo "   Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
    fi

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=$AWS_REGION

    echo "✅ AWS credentials configured"
    echo "   Region: $AWS_REGION"

    # Install Terraform if not present
    if ! command -v terraform &> /dev/null; then
        echo "📦 Installing Terraform..."
        if [ "$OS" == "linux" ]; then
            TERRAFORM_VERSION="1.6.0"
            wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -O /tmp/terraform.zip
            unzip -q -o /tmp/terraform.zip -d /tmp
            sudo mv /tmp/terraform /usr/local/bin/
            rm /tmp/terraform.zip
            echo "✅ Terraform installed"
        elif [ "$OS" == "macos" ]; then
            if command -v brew &> /dev/null; then
                brew install terraform
            else
                echo "❌ Please install Terraform: brew install terraform"
                exit 1
            fi
        fi
    else
        TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
        echo "✅ Terraform already installed: $TERRAFORM_VERSION"
    fi

    # Setup infrastructure with Terraform
    if [ "$SKIP_INFRASTRUCTURE" != "true" ]; then
        echo "🏗️  Setting up infrastructure with Terraform..."
        cd infrastructure/terraform

        # Export Terraform variables
        export TF_VAR_aws_region=${TF_VAR_aws_region:-$AWS_REGION}
        export TF_VAR_ec2_instance_type=${TF_VAR_ec2_instance_type:-$EC2_INSTANCE_TYPE}
        export TF_VAR_ec2_key_name=${TF_VAR_ec2_key_name:-$EC2_KEY_NAME}
        export TF_VAR_ec2_ami_id=${TF_VAR_ec2_ami_id:-}

        terraform init || {
            echo "❌ Terraform init failed"
            exit 1
        }

        terraform plan -out=tfplan || {
            echo "⚠️  Terraform plan failed, continuing..."
        }

        terraform apply -auto-approve || {
            echo "⚠️  Infrastructure may already exist, continuing..."
        }

        cd ../..
        echo "✅ Infrastructure setup completed"
    else
        echo "⏭️  Skipping infrastructure creation (SKIP_INFRASTRUCTURE=true)"
    fi

    # Get EC2 instance IP
    echo "🔍 Getting EC2 instance IP..."
    INSTANCE_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=absenteeism-api" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "")

    if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" == "None" ]; then
        echo "❌ Could not find running EC2 instance with tag Name=absenteeism-api"
        exit 1
    fi

    echo "✅ Found EC2 instance at: $INSTANCE_IP"
    echo ""

    # Setup SSH and deploy to EC2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 STEP 5: Deploying to EC2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Expand SSH key path
    SSH_KEY_PATH="${EC2_SSH_KEY_PATH/#\~/$HOME}"
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "❌ SSH key not found at: $SSH_KEY_PATH"
        echo "   Update EC2_SSH_KEY_PATH in .env"
        exit 1
    fi

    # Setup SSH
    mkdir -p ~/.ssh
    chmod 600 "$SSH_KEY_PATH"
    ssh-keyscan -H "$INSTANCE_IP" >> ~/.ssh/known_hosts 2>/dev/null || true

    # Copy files to EC2
    echo "📤 Copying files to EC2..."
    scp -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" -r \
        . "$EC2_USER@$INSTANCE_IP:~/absenteeism_at_work/" || {
        echo "❌ Failed to copy files to EC2"
        exit 1
    }

    # Execute deployment on EC2
    echo "🚀 Executing deployment on EC2..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$INSTANCE_IP" << EOF
        cd ~/absenteeism_at_work
        export DEPLOYMENT_MODE=local
        chmod +x scripts/deploy.sh
        ./scripts/deploy.sh
EOF

    # Health check
    echo "⏳ Waiting for API to be ready..."
    sleep 30
    if curl -f -s "http://$INSTANCE_IP:8000/health" > /dev/null; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 Deployment completed successfully!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📍 API Endpoints:"
        echo "   • API Base:      http://$INSTANCE_IP:8000"
        echo "   • Frontend:      http://$INSTANCE_IP:8000/"
        echo "   • Health Check:  http://$INSTANCE_IP:8000/health"
        echo "   • API Docs:      http://$INSTANCE_IP:8000/docs"
        echo "   • MLflow UI:     http://$INSTANCE_IP:5001"
        echo ""
    else
        echo "❌ Health check failed"
        exit 1
    fi

    exit 0
fi

# ==========================================
# STEP 4/5: Local Docker Deployment
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 STEP 4: Setting up Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install Docker if needed (Linux only)
if [ "$OS" == "linux" ] && ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker $USER
    rm /tmp/get-docker.sh
    echo "⚠️  Docker group changes require logout/login or run: newgrp docker"
    newgrp docker <<EOF || true
echo "Docker group activated"
EOF
fi

# Install Docker Compose if needed (Linux only)
if [ "$OS" == "linux" ] && ! command -v docker-compose &> /dev/null; then
    echo "🔧 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Verify Docker
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running or user doesn't have permissions"
    if [ "$OS" == "linux" ]; then
        echo "   Try: sudo systemctl start docker"
    else
        echo "   Start Docker Desktop"
    fi
    exit 1
fi

DOCKER_VERSION=$(docker --version)
echo "✅ Docker: $DOCKER_VERSION"
echo ""

# Clean up Docker system (matching GitHub Actions)
echo "🧹 Cleaning up Docker system..."
docker system prune -af --volumes || true
docker builder prune -af || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 STEP 5: Deploying API with Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Build Docker image (matching GitHub Actions)
if [ "$SKIP_DOCKER_BUILD" != "true" ]; then
    echo "🏗️  Building Docker image..."
    docker-compose build --no-cache || {
        echo "❌ Docker build failed"
        docker-compose logs 2>&1 | tail -50
        exit 1
    }
else
    echo "⏭️  Skipping Docker build (SKIP_DOCKER_BUILD=true)"
fi

# Start containers
echo "🚀 Starting containers..."
docker-compose up -d || {
    echo "❌ Failed to start containers"
    docker-compose logs --tail=50
    exit 1
}

# Clean up after build (matching GitHub Actions)
docker system prune -af || true

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
    echo "   • MLflow UI:     http://localhost:5001"
    echo ""
    echo "📋 Useful Commands:"
    echo "   • View logs:     docker-compose logs -f"
    echo "   • Stop API:      docker-compose down"
    echo "   • Restart API:   docker-compose restart"
    echo "   • Check status:  docker-compose ps"
    echo ""

    # Show external access info for EC2
    if [ "$IS_EC2" == "true" ]; then
        EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
        if [ -n "$EC2_IP" ]; then
            echo "🌐 External Access:"
            echo "   • http://$EC2_IP:8000"
            echo "   • http://$EC2_IP:8000/docs"
            echo ""
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

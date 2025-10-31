#!/bin/bash
# Script to setup AWS infrastructure using Terraform

set -e

echo "🏗️  Setting up AWS infrastructure..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "📦 Installing Terraform..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
        unzip terraform_1.6.0_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_1.6.0_linux_amd64.zip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install terraform || {
            echo "❌ Please install Terraform: brew install terraform"
            exit 1
        }
    fi
fi

cd infrastructure/terraform

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars..."
    cat > terraform.tfvars <<EOF
aws_region         = "us-east-1"
ec2_instance_type  = "t3.micro"
ec2_key_name       = "absenteeism-key"  # Update with your key name
EOF
    echo "⚠️  Please update terraform.tfvars with your settings"
fi

# Plan
echo "📋 Planning infrastructure..."
terraform plan

# Apply
echo "🚀 Creating infrastructure..."
read -p "Continue with infrastructure creation? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve
    echo ""
    echo "✅ Infrastructure created!"
    echo ""
    terraform output
else
    echo "❌ Infrastructure creation cancelled"
    exit 1
fi


#!/bin/bash
# Script to fix EC2 instance key pair by recreating the instance

set -e

echo "🔧 Fixing EC2 Key Pair Issue"
echo ""

# Load environment variables if .env exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

AWS_REGION=${AWS_REGION:-us-east-1}
KEY_NAME=${EC2_KEY_NAME:-absenteeism-key}

echo "Region: $AWS_REGION"
echo "Key Name: $KEY_NAME"
echo ""

# Verify key exists in AWS
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "❌ Key pair '$KEY_NAME' not found in AWS"
    echo "   Create it first: ./scripts/generate_keypair.sh"
    exit 1
fi

echo "✅ Key pair '$KEY_NAME' found in AWS"
echo ""

# Go to terraform directory
cd infrastructure/terraform

echo "🔍 Checking current instance state..."
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  No instance found in Terraform state"
    echo "   Applying Terraform with key pair..."
    terraform init
    terraform apply -var="ec2_key_name=$KEY_NAME" -var="aws_region=$AWS_REGION" -auto-approve
    echo "✅ Infrastructure created/updated"
    exit 0
fi

echo "📋 Current instance ID: $INSTANCE_ID"

# Check if instance has key pair
CURRENT_KEY=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].KeyName' \
    --output text)

if [ "$CURRENT_KEY" == "$KEY_NAME" ]; then
    echo "✅ Instance already has correct key pair: $KEY_NAME"
    exit 0
fi

echo "⚠️  Current key pair: ${CURRENT_KEY:-None}"
echo "🔄 Need to recreate instance with key pair: $KEY_NAME"
echo ""

read -p "This will recreate the EC2 instance. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

echo ""
echo "🗑️  Tainting instance to force recreation..."
terraform taint aws_instance.api || echo "⚠️  Instance not in state, will be created fresh"

echo ""
echo "🏗️  Applying Terraform with key pair..."
terraform apply -var="ec2_key_name=$KEY_NAME" -var="aws_region=$AWS_REGION" -auto-approve

echo ""
echo "✅ Instance recreated with key pair: $KEY_NAME"
echo ""
echo "🔍 New instance details:"
terraform output

cd ../..

echo ""
echo "✅ Done! You can now SSH using:"
echo "   ssh -i absenteeism-key.pem ubuntu@$(cd infrastructure/terraform && terraform output -raw instance_ip)"


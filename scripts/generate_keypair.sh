#!/bin/bash
# Script to generate a new AWS EC2 Key Pair

set -e

# Load environment variables if .env exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Set defaults
AWS_REGION=${AWS_REGION:-us-east-1}
KEY_NAME=${EC2_KEY_NAME:-absenteeism-key}
OUTPUT_FILE="${KEY_NAME}.pem"

echo "🔑 Generating AWS EC2 Key Pair..."
echo "   Region: $AWS_REGION"
echo "   Key Name: $KEY_NAME"
echo "   Output File: $OUTPUT_FILE"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    echo "   Install it: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

# Check if key already exists
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "⚠️  Key pair '$KEY_NAME' already exists in AWS"
    read -p "Do you want to delete it and create a new one? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing key pair..."
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION"
        echo "✅ Key pair deleted"
    else
        echo "❌ Cancelled. Please use a different key name or delete the existing one manually."
        exit 1
    fi
fi

# Generate new key pair
echo "🔑 Creating new key pair..."
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$AWS_REGION" \
    --query 'KeyMaterial' \
    --output text > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    # Set proper permissions
    chmod 400 "$OUTPUT_FILE"
    
    echo ""
    echo "✅ Key pair created successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Key file saved to: $OUTPUT_FILE"
    echo "   2. Add to .gitignore (already done)"
    echo "   3. Update GitHub Secret EC2_SSH_KEY with the content of $OUTPUT_FILE:"
    echo "      cat $OUTPUT_FILE"
    echo ""
    echo "   4. Update .env with:"
    echo "      EC2_KEY_NAME=$KEY_NAME"
    echo "      EC2_SSH_KEY_PATH=$OUTPUT_FILE"
    echo ""
    echo "   5. Update infrastructure/terraform/terraform.tfvars (or TF_VAR_ec2_key_name in .env)"
    echo "      ec2_key_name = \"$KEY_NAME\""
    echo ""
    echo "⚠️  IMPORTANT: Save this key file securely! You cannot retrieve it again from AWS."
else
    echo "❌ Failed to create key pair"
    exit 1
fi

